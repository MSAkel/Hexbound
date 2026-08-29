extends Node

## Headless balance playtest. Instantiates a live hex map, skips presentation,
## and writes user://playtest_report.json (or playtest_report_<layout>.json).
##
## godot --headless --path "E:/Godot/game++" res://scenes/debug/playtest_runner.tscn
## Restrict to one layout with `-- --layout=surveyor`.

const HEX_MAP_SCENE := preload("res://scenes/hex_tile_map.tscn")
const REPORT_PATH := "user://playtest_report.json"
const STARTER_SEED_COUNT := 16
const R1_BOT_SEED_COUNT := 4
const FULL_RUN_SEED_COUNT := 4
const FULL_RUN_TARGET_ROUND := 9
const MERCHANT_STOCK_COUNT := 3
## fill: next empty hex in trigger order. stack: pile Energy and Mult on one line.
## spread: put each new card on the emptiest legal segment.
const BOT_IDS: Array[String] = ["fill", "stack", "spread"]
const CHARACTER_IDS: Array[String] = [
	"surveyor",
	"encircler",
	"spiralist",
	"columnist",
	"converger",
]
const ALLOWED_FILLER_IDS: Array[String] = ["incremental", "rising_tempo", "spark_plug"]
const BANNED_FILLER_IDS: Array[String] = ["compact_power", "edge_card", "treasury"]
const LOCKED_STARTER_IDS: Array[String] = ["power_cell", "basic_mult"]

var _map: HexTileMap
var _cases: Array[Dictionary] = []
var _failed := 0
var _active_bot: String = "fill"
var _layouts: Array[String] = []
var _report_path := REPORT_PATH
var _only_bot := ""
var _only_seed := ""


func _enter_tree() -> void:
	GameManager.skip_presentation = true


func _ready() -> void:
	_layouts = _parse_layout_filter()
	if _layouts.size() == 1:
		_report_path = "user://playtest_report_%s.json" % _layouts[0]
	print("[playtest] layouts=%s bot=%s seed=%s" % [
		",".join(_layouts),
		_only_bot if not _only_bot.is_empty() else "all",
		_only_seed if not _only_seed.is_empty() else "all",
	])
	_map = HEX_MAP_SCENE.instantiate() as HexTileMap
	add_child(_map)
	await get_tree().process_frame
	await _run_all()
	_write_report()
	get_tree().quit(1 if _failed > 0 else 0)


func _parse_layout_filter() -> Array[String]:
	var requested: Array[String] = []
	var env_layout := OS.get_environment("PLAYTEST_LAYOUT").strip_edges().to_lower()
	if not env_layout.is_empty():
		requested.append(env_layout)
	for arg in OS.get_cmdline_user_args():
		var value := ""
		if arg.begins_with("--layout="):
			value = arg.substr("--layout=".length())
		elif arg.begins_with("layout="):
			value = arg.substr("layout=".length())
		else:
			continue
		requested.append(value.strip_edges().to_lower())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bot="):
			_only_bot = arg.substr("--bot=".length()).strip_edges().to_lower()
		elif arg.begins_with("--seed="):
			_only_seed = arg.substr("--seed=".length()).strip_edges()
	var layouts: Array[String] = []
	for character_id: String in CHARACTER_IDS:
		if requested.is_empty() or character_id in requested:
			layouts.append(character_id)
	if layouts.is_empty():
		push_error("PlaytestRunner: no matching layout in %s" % str(requested))
		return CHARACTER_IDS.duplicate()
	return layouts


func _run_all() -> void:
	if not _only_seed.is_empty():
		var bot_id := _only_bot if not _only_bot.is_empty() else "stack"
		var character_id := _layouts[0]
		print("[playtest] focused full_nine/%s %s %s" % [bot_id, character_id, _only_seed])
		await _run_one_full_nine(character_id, _only_seed, bot_id)
		return
	_run_starter_fairness()
	_run_lone_cell_legality()
	if "surveyor" in _layouts:
		await _run_gold_engines()
	await _run_two_segment_r1()
	await _run_full_nines()


func _run_starter_fairness() -> void:
	for character_id: String in _layouts:
		GameManager.selected_character = PlayerCharacter.get_character_by_id(character_id)
		GameManager.selected_difficulty = Difficulty.Level.LEVEL_0
		for index in STARTER_SEED_COUNT:
			var seed_text := _seed_for("ST", character_id, index)
			RunRng.begin_new_run(seed_text)
			var hand := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
			var ids: Array[String] = []
			for card: TileCard in hand:
				ids.append(card.id)

			var reasons: Array[String] = []
			for locked_id: String in LOCKED_STARTER_IDS:
				if locked_id not in ids:
					reasons.append("missing locked starter %s" % locked_id)

			var filler_ids: Array[String] = []
			for card_id: String in ids:
				if card_id in LOCKED_STARTER_IDS:
					continue
				var template := GameManager.get_tile_card_by_id(card_id)
				if template != null and template.type == TileCard.TileCardType.PRODUCER:
					filler_ids.append(card_id)

			if filler_ids.size() != 1:
				reasons.append("expected 1 filler producer, got %s" % str(filler_ids))
			else:
				var filler_id := filler_ids[0]
				if filler_id not in ALLOWED_FILLER_IDS:
					reasons.append("filler %s is not Incremental / Rising Tempo / Spark Plug" % filler_id)
				if filler_id in BANNED_FILLER_IDS:
					reasons.append("banned filler %s" % filler_id)

			_record(
				"starter_fairness",
				character_id,
				seed_text,
				reasons.is_empty(),
				reasons,
				{"hand": ids, "filler": filler_ids}
			)


func _run_lone_cell_legality() -> void:
	var lone := GameManager.get_tile_card_by_id("lone_cell")
	if lone == null:
		_record("lone_cell_legality", "n/a", "", false, ["lone_cell missing from pool"], {})
		return

	for character_id: String in _layouts:
		var character := PlayerCharacter.get_character_by_id(character_id)
		GameManager.selected_character = character
		var legal := lone.is_legal_for_layout(character)
		var expect_legal := character.has_segment_of_size(1)
		var reasons: Array[String] = []
		if legal != expect_legal:
			reasons.append(
				"is_legal_for_layout=%s expected %s (has 1-tile segment=%s)"
				% [legal, expect_legal, expect_legal]
			)

		RunRng.begin_new_run("LONECELL")
		var drew_lone := false
		for _i in 80:
			var pack := RuneLoot.draw_runes(3, GameManager.tile_cards_pool, true, RunRng.create_rng("lone_draw:%d" % _i))
			for card: TileCard in pack:
				if card.id == "lone_cell":
					drew_lone = true
					break
			if drew_lone:
				break

		if drew_lone and not expect_legal:
			reasons.append("packs offered Lone Cell on a layout with no 1-tile segment")
		if expect_legal and not legal:
			reasons.append("Encircler should allow Lone Cell")

		_record(
			"lone_cell_legality",
			character_id,
			"LONECELL",
			reasons.is_empty(),
			reasons,
			{
				"legal": legal,
				"has_one_tile_segment": expect_legal,
				"drew_lone_in_sample": drew_lone,
			}
		)


func _run_gold_engines() -> void:
	await _run_treasury_at_zero_gold()
	await _run_prosperity_vs_allowance()
	await _run_lucky_draw_gold_branch()


func _run_treasury_at_zero_gold() -> void:
	_begin_run("surveyor", "TREASURY")
	GoldManager.set_amount(0)
	var hex := _first_empty_hex()
	_place_by_id(hex, "treasury")
	await _resolve_turn()
	var energy := _map.get_segment_turn_score(_map.get_segment_index(hex.coordinates))
	var reasons: Array[String] = []
	if energy != 6:
		reasons.append("Treasury at 0 gold scored %d Energy, expected 6" % energy)
	_record(
		"gold_engine_treasury_zero",
		"surveyor",
		"TREASURY",
		reasons.is_empty(),
		reasons,
		{"energy": energy, "gold": GoldManager.amount}
	)


func _run_prosperity_vs_allowance() -> void:
	await _run_prosperity_order(true)
	await _run_prosperity_order(false)


func _run_prosperity_order(allowance_first: bool) -> void:
	var label := "gold_engine_prosperity_after_allowance" if allowance_first else "gold_engine_prosperity_before_allowance"
	_begin_run("surveyor", "PROSPER1" if allowance_first else "PROSPER0")
	GoldManager.set_amount(0)
	var pair := _two_hexes_in_same_segment()
	if pair.is_empty():
		_record(label, "surveyor", "", false, ["could not find two tiles in one segment"], {})
		return

	var first: Hex = pair[0]
	var second: Hex = pair[1]
	if allowance_first:
		_place_by_id(first, "basic_allowance")
		_place_by_id(second, "prosperity")
	else:
		_place_by_id(first, "prosperity")
		_place_by_id(second, "basic_allowance")

	await _resolve_turn()
	var segment_index := _map.get_segment_index(first.coordinates)
	var energy := _map.get_segment_turn_score(segment_index)
	var expected := 12 if allowance_first else 8
	var reasons: Array[String] = []
	if energy != expected:
		reasons.append("Prosperity Energy %d, expected %d" % [energy, expected])
	if GoldManager.amount != 1:
		reasons.append("gold after turn is %d, expected 1 from Allowance" % GoldManager.amount)

	_record(
		label,
		"surveyor",
		RunRng.get_display_seed(),
		reasons.is_empty(),
		reasons,
		{"energy": energy, "gold": GoldManager.amount, "allowance_first": allowance_first}
	)


func _run_lucky_draw_gold_branch() -> void:
	var found := false
	var last_gold := 0
	var last_energy := 0
	var used_seed := ""
	for index in 24:
		used_seed = _seed_for("LD", "surveyor", index)
		_begin_run("surveyor", used_seed)
		GoldManager.set_amount(0)
		var hex := _first_empty_hex()
		_place_by_id(hex, "lucky_draw")
		var lucky := hex.active_tile_card
		lucky.current_chance = 1.0
		if not _lucky_draw_peeks_gold(hex, lucky):
			continue
		await _resolve_turn()
		found = GoldManager.amount == 8
		last_gold = GoldManager.amount
		last_energy = _map.get_segment_turn_score(_map.get_segment_index(hex.coordinates))
		if found:
			break

	var reasons: Array[String] = []
	if not found:
		reasons.append("never hit Lucky Draw 8-gold branch (last gold=%d energy=%d)" % [last_gold, last_energy])
	_record(
		"gold_engine_lucky_draw_8_gold",
		"surveyor",
		used_seed,
		reasons.is_empty(),
		reasons,
		{"gold": last_gold, "energy": last_energy}
	)


func _lucky_draw_peeks_gold(hex: Hex, lucky: TileCard) -> bool:
	var rng := RunRng.create_card_effect_rng(hex, lucky)
	rng.randf()
	return rng.randf() >= 0.5


func _run_two_segment_r1() -> void:
	for character_id: String in _layouts:
		for index in R1_BOT_SEED_COUNT:
			var seed_text := _seed_for("R1", character_id, index)
			await _run_one_two_segment_r1(character_id, seed_text)


func _run_one_two_segment_r1(character_id: String, seed_text: String) -> void:
	_begin_run(character_id, seed_text)
	var hand := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
	var hand_ids: Array[String] = []
	for card: TileCard in hand:
		hand_ids.append(card.id)

	var segment_pair := _pick_two_smallest_segments(hand.size())
	var reasons: Array[String] = []
	if segment_pair.is_empty():
		reasons.append("no two segments large enough for the opening hand")
		_record("two_segment_r1", character_id, seed_text, false, reasons, {"hand": hand_ids})
		return

	var placed := _place_hand_on_two_segments(hand, segment_pair)
	if not placed:
		reasons.append("could not place the opening hand on segments %s" % str(segment_pair))
		_record("two_segment_r1", character_id, seed_text, false, reasons, {"hand": hand_ids, "segments": segment_pair})
		return

	if _cards_on_one_segment_only():
		reasons.append("whole hand landed on one segment")

	var turns_used := 0
	var r1_goal := GameManager.required_score
	while GameManager.remaining_turns > 0 and GameManager.total_round_score < r1_goal:
		await _resolve_turn()
		turns_used += 1

	var r1_score := GameManager.total_round_score
	var r1_cleared := r1_score >= r1_goal
	if not r1_cleared:
		reasons.append("R1 score %d / %d after %d turns" % [r1_score, r1_goal, turns_used])

	var r2_score := -1
	var r2_cleared := false
	var r2_goal := -1
	if r1_cleared:
		GameManager.advance_round()
		EventBus.turn_started.emit()
		r2_goal = GameManager.required_score
		while GameManager.remaining_turns > 0 and GameManager.total_round_score < r2_goal:
			await _resolve_turn()
		r2_score = GameManager.total_round_score
		r2_cleared = r2_score >= r2_goal

	_record(
		"two_segment_r1",
		character_id,
		seed_text,
		reasons.is_empty(),
		reasons,
		{
			"hand": hand_ids,
			"segments": segment_pair,
			"r1_score": r1_score,
			"r1_goal": r1_goal,
			"r1_cleared": r1_cleared,
			"turns_used": turns_used,
			"r2_same_board_score": r2_score,
			"r2_same_board_goal": r2_goal,
			"r2_same_board_cleared": r2_cleared,
			"gold": GoldManager.amount,
			"note": "R2 is same-board with no shop or packs. Informational only.",
		}
	)


func _run_full_nines() -> void:
	for bot_id: String in BOT_IDS:
		_active_bot = bot_id
		for character_id: String in _layouts:
			for index in FULL_RUN_SEED_COUNT:
				var seed_text := _seed_for("F9", character_id, index)
				await _run_one_full_nine(character_id, seed_text, bot_id)
	_print_full_nine_summary()


func _run_one_full_nine(character_id: String, seed_text: String, bot_id: String) -> void:
	_active_bot = bot_id
	print("[playtest] start full_nine/%s %s %s" % [bot_id, character_id, seed_text])
	_begin_run(character_id, seed_text)
	var hand := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
	_place_opening_hand(hand)
	if not _only_seed.is_empty():
		_print_board("after opening hand")

	var round_log: Array[Dictionary] = []
	var picks: Array[String] = []
	var buys: Array[String] = []
	var lost_round := 0
	var won := false

	while GameManager.current_round <= FULL_RUN_TARGET_ROUND:
		var round_number := GameManager.current_round
		var goal := GameManager.required_score
		var turns_used := 0
		while GameManager.remaining_turns > 0 and GameManager.total_round_score < goal:
			await _resolve_turn()
			turns_used += 1
			if GameManager.total_round_score >= goal:
				break
			# Fail-turn packs roll remaining_turns before it is consumed. After resolve it is already -1.
			if GameManager.remaining_turns <= 0:
				break
			var picked := _draft_and_pick_pack(false, round_number, GameManager.remaining_turns + 1)
			if picked != null:
				picks.append("%s:%s" % [round_number, picked.id])
				_place_one_card(picked)

		var score := GameManager.total_round_score
		var cleared := score >= goal
		round_log.append({
			"round": round_number,
			"goal": goal,
			"score": score,
			"turns_used": turns_used,
			"gold": GoldManager.amount,
			"cleared": cleared,
			"challenge": ChallengeManager.get_active_challenge_name(),
		})
		if not _only_seed.is_empty():
			_print_board("after round %d score=%d/%d" % [round_number, score, goal])
		if not cleared:
			lost_round = round_number
			break
		if round_number >= FULL_RUN_TARGET_ROUND:
			won = true
			break

		GoldManager.apply_round_speed_rewards(GameManager.get_skipped_turns())
		var completed_round := round_number
		# Reward pack size still belongs to the round that just ended.
		var reward := _draft_and_pick_pack(true, completed_round, 0)
		GameManager.advance_round()
		if reward != null:
			picks.append("reward%s:%s" % [completed_round, reward.id])
			_place_one_card(reward)
		buys.append_array(_shop_current_round())
		EventBus.turn_started.emit()

	var reasons: Array[String] = []
	if not won:
		reasons.append("lost on round %d with score %d / %d" % [
			lost_round,
			GameManager.total_round_score,
			GameManager.required_score,
		])
	_record(
		"full_nine",
		character_id,
		seed_text,
		won,
		reasons,
		{
			"won": won,
			"reached_round": GameManager.current_round,
			"gold": GoldManager.amount,
			"picks": picks,
			"buys": buys,
			"rounds": round_log,
			"bot": bot_id,
			"segment_sizes": GameManager.selected_character.segment_sizes,
			"segments_count": GameManager.selected_character.segments_count,
		}
	)


func _draft_and_pick_pack(is_reward: bool, round_number: int, fail_remaining_turns: int) -> TileCard:
	var stream_name := RunRng.build_rune_offer_stream_name(
		round_number,
		fail_remaining_turns,
		is_reward,
		0
	)
	var pack := RuneLoot.draw_runes(
		ChallengeManager.get_runes_pack_size(),
		GameManager.tile_cards_pool,
		true,
		RunRng.create_rng(stream_name)
	)
	if pack.is_empty():
		return null
	pack.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return _card_keep_value(a) > _card_keep_value(b)
	)
	for card: TileCard in pack:
		if _can_bot_place_card(card):
			return card
	return null


func _shop_current_round() -> Array[String]:
	var bought: Array[String] = []
	var stream_name := RunRng.build_merchant_stream_name(GameManager.current_round, 0)
	var stock := RuneLoot.draw_runes(
		MERCHANT_STOCK_COUNT,
		GameManager.tile_cards_pool,
		true,
		RunRng.create_rng(stream_name)
	)
	stock.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return _card_keep_value(a) > _card_keep_value(b)
	)
	for card: TileCard in stock:
		if not _can_bot_place_card(card):
			continue
		var price := card.get_shop_price()
		if not GoldManager.can_afford(price):
			continue
		GoldManager.remove(price)
		bought.append("%s:%s@%d" % [GameManager.current_round, card.id, price])
		_place_one_card(card)
	return bought


func _card_keep_value(card: TileCard) -> float:
	if card.type == TileCard.TileCardType.UTILITY:
		return 1.0
	match card.product:
		TileCard.Product.MULTIPLIER:
			return 40.0 + float(card.base_production_amount) * 20.0
		TileCard.Product.SCORE:
			return 10.0 + float(card.base_production_amount)
		TileCard.Product.GOLD:
			return 12.0 + float(card.base_production_amount) * 8.0
		_:
			return 8.0


func _can_bot_place_card(card: TileCard) -> bool:
	if card == null:
		return false
	# Utilities target occupied tiles and need a two-step play the bot does not do.
	if card.type == TileCard.TileCardType.UTILITY:
		return false
	if not card.is_legal_for_layout(GameManager.selected_character):
		return false
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.is_disabled_by_difficulty or hex.active_tile_card != null:
			continue
		if card.can_place_on_tile(hex):
			return true
	return false


func _place_opening_hand(hand: Array[TileCard]) -> void:
	match _active_bot:
		"stack":
			if _place_hand_on_largest_segments(hand):
				return
		"spread":
			for card: TileCard in _order_hand_for_line(hand):
				_place_one_card(card)
			return
		_:
			var opening := _pick_two_smallest_segments(hand.size())
			if not opening.is_empty() and _place_hand_on_two_segments(hand, opening):
				return
	for card: TileCard in hand:
		_place_one_card(card)


func _place_hand_on_largest_segments(hand: Array[TileCard]) -> bool:
	var ordered := _order_hand_for_line(hand)
	var ranked: Array[int] = []
	for index in _map.get_segment_count():
		ranked.append(index)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var size_a := _map.get_segment_size(a)
		var size_b := _map.get_segment_size(b)
		if size_a != size_b:
			return size_a > size_b
		return a < b
	)
	var remaining := ordered.duplicate()
	for segment_index: int in ranked:
		if remaining.is_empty():
			break
		var slots := _empty_hexes_in_segment(segment_index)
		var placed_here := 0
		var still_pending: Array[TileCard] = []
		for card: TileCard in remaining:
			if placed_here >= slots.size():
				still_pending.append(card)
				continue
			if _place_on_first_legal(card, slots):
				placed_here += 1
			else:
				still_pending.append(card)
		remaining = still_pending
	return remaining.is_empty()


func _place_one_card(card: TileCard) -> bool:
	if not _can_bot_place_card(card):
		return false
	match _active_bot:
		"stack":
			if _place_on_preferred_segments(card, _stack_segment_rank()):
				return true
		"spread":
			if _place_on_preferred_segments(card, _spread_segment_rank()):
				return true
	return _place_first_legal_empty(card)


func _place_first_legal_empty(card: TileCard) -> bool:
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.is_disabled_by_difficulty or hex.active_tile_card != null:
			continue
		if not card.can_place_on_tile(hex):
			continue
		hex.place_tile_card(card)
		return true
	return false


func _place_on_preferred_segments(card: TileCard, ranked_segments: Array[int]) -> bool:
	for segment_index: int in ranked_segments:
		var slots := _empty_hexes_in_segment(segment_index)
		if _place_on_first_legal(card, slots):
			return true
	return false


func _stack_segment_rank() -> Array[int]:
	var ranked: Array[int] = []
	for index in _map.get_segment_count():
		ranked.append(index)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var score_a := _segment_product_count(a, TileCard.Product.SCORE)
		var score_b := _segment_product_count(b, TileCard.Product.SCORE)
		var mult_a := _segment_product_count(a, TileCard.Product.MULTIPLIER)
		var mult_b := _segment_product_count(b, TileCard.Product.MULTIPLIER)
		var combo_a := score_a + mult_a * 3 + _segment_card_count(a)
		var combo_b := score_b + mult_b * 3 + _segment_card_count(b)
		if combo_a != combo_b:
			return combo_a > combo_b
		var size_a := _map.get_segment_size(a)
		var size_b := _map.get_segment_size(b)
		if size_a != size_b:
			return size_a > size_b
		return a < b
	)
	return ranked


func _spread_segment_rank() -> Array[int]:
	var ranked: Array[int] = []
	for index in _map.get_segment_count():
		ranked.append(index)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var count_a := _segment_card_count(a)
		var count_b := _segment_card_count(b)
		if count_a == count_b:
			return a < b
		return count_a < count_b
	)
	return ranked


func _segment_card_count(segment_index: int) -> int:
	var count := 0
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if _map.get_segment_index(hex.coordinates) != segment_index:
			continue
		if hex.active_tile_card != null:
			count += 1
	return count


func _segment_product_count(segment_index: int, product: TileCard.Product) -> int:
	var count := 0
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if _map.get_segment_index(hex.coordinates) != segment_index:
			continue
		var card := hex.active_tile_card
		if card != null and card.product == product:
			count += 1
	return count


func _begin_run(character_id: String, seed_text: String) -> void:
	GameManager.skip_presentation = true
	GameManager.selected_character = PlayerCharacter.get_character_by_id(character_id)
	GameManager.selected_difficulty = Difficulty.Level.LEVEL_0
	RunRng.begin_new_run(seed_text)
	GameManager.reset_for_new_run()
	GoldManager.set_run_starting_gold(GameManager.selected_difficulty)
	RerollManager.reset_for_new_run()
	ChallengeManager.init_run()
	_clear_board()
	_map.generate_terrain()
	_map.apply_run_start_randomization()
	EventBus.turn_started.emit()


func _clear_board() -> void:
	if _map == null:
		return
	for hex: Hex in _map.map_data.values():
		if hex.active_tile_card != null:
			hex.remove_tile_card()
	_map.reset_segment_turn_results()


func _place_by_id(hex: Hex, card_id: String) -> void:
	var template := GameManager.get_tile_card_by_id(card_id)
	if hex == null or template == null:
		return
	hex.place_tile_card(template)


func _first_empty_hex() -> Hex:
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.active_tile_card == null and not hex.is_disabled_by_difficulty:
			return hex
	return null


func _two_hexes_in_same_segment() -> Array[Hex]:
	var found: Array[Hex] = []
	var segment_index := -1
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.is_disabled_by_difficulty:
			continue
		var index := _map.get_segment_index(hex.coordinates)
		if found.is_empty():
			segment_index = index
			found.append(hex)
			continue
		if index == segment_index:
			found.append(hex)
			return found
		found.clear()
		segment_index = index
		found.append(hex)
	return []


func _pick_two_smallest_segments(min_tiles: int) -> Array[int]:
	var entries: Array[Dictionary] = []
	for index in _map.get_segment_count():
		entries.append({"index": index, "size": _map.get_segment_size(index)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.size) == int(b.size):
			return int(a.index) < int(b.index)
		return int(a.size) < int(b.size)
	)
	for i in entries.size():
		for j in range(i + 1, entries.size()):
			var a: Dictionary = entries[i]
			var b: Dictionary = entries[j]
			if int(a.size) + int(b.size) >= min_tiles:
				var pair: Array[int] = [int(a.index), int(b.index)]
				pair.sort()
				return pair
	return []


func _place_hand_on_two_segments(hand: Array[TileCard], segments: Array[int]) -> bool:
	var ordered := _order_hand_for_line(hand)
	var primary := segments[0]
	var secondary := segments[1]
	if _map.get_segment_size(primary) < _map.get_segment_size(secondary):
		primary = segments[1]
		secondary = segments[0]

	# Keep Energy and Mult on the larger of the two lines. Spill the rest.
	var primary_slots := _empty_hexes_in_segment(primary)
	var secondary_slots := _empty_hexes_in_segment(secondary)
	if primary_slots.size() + secondary_slots.size() < ordered.size():
		return false

	# Do not dump the whole hand on one line even when it fits.
	var spill_count := 0
	if ordered.size() >= 2 and not secondary_slots.is_empty():
		spill_count = 1
	var primary_count := mini(ordered.size() - spill_count, primary_slots.size())
	spill_count = ordered.size() - primary_count
	if spill_count > secondary_slots.size():
		return false

	for i in primary_count:
		if not _place_on_first_legal(ordered[i], primary_slots):
			return false
	for i in spill_count:
		if not _place_on_first_legal(ordered[primary_count + i], secondary_slots):
			return false
	return true


func _place_on_first_legal(card: TileCard, slots: Array[Hex]) -> bool:
	for index in slots.size():
		var hex: Hex = slots[index]
		if hex.active_tile_card != null:
			continue
		if not card.can_place_on_tile(hex):
			continue
		hex.place_tile_card(card)
		slots.remove_at(index)
		return true
	return false


func _order_hand_for_line(hand: Array[TileCard]) -> Array[TileCard]:
	var score_cards: Array[TileCard] = []
	var gold_cards: Array[TileCard] = []
	var mult_cards: Array[TileCard] = []
	var other_cards: Array[TileCard] = []
	for card: TileCard in hand:
		match card.product:
			TileCard.Product.SCORE:
				score_cards.append(card)
			TileCard.Product.GOLD:
				gold_cards.append(card)
			TileCard.Product.MULTIPLIER:
				mult_cards.append(card)
			_:
				other_cards.append(card)
	var ordered: Array[TileCard] = []
	ordered.append_array(score_cards)
	ordered.append_array(gold_cards)
	ordered.append_array(mult_cards)
	ordered.append_array(other_cards)
	return ordered


func _empty_hexes_in_segment(segment_index: int) -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if _map.get_segment_index(hex.coordinates) != segment_index:
			continue
		if hex.active_tile_card != null or hex.is_disabled_by_difficulty:
			continue
		hexes.append(hex)
	return hexes


func _cards_on_one_segment_only() -> bool:
	var used: Dictionary = {}
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.active_tile_card == null:
			continue
		used[_map.get_segment_index(hex.coordinates)] = true
	return used.size() <= 1


func _resolve_turn() -> void:
	EventBus.turn_ended.emit()
	while GameManager.is_processing_turn:
		await get_tree().process_frame


func _seed_for(prefix: String, character_id: String, index: int) -> String:
	var tag := character_id.substr(0, 3).to_upper()
	return "%s%s%03d" % [prefix, tag, index]


func _print_board(label: String) -> void:
	print("[playtest] board %s round=%d" % [label, GameManager.current_round])
	if _map == null:
		return
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.active_tile_card == null:
			continue
		print(
			"[playtest]   seg=%d %s %s"
			% [_map.get_segment_index(hex.coordinates), str(hex.coordinates), hex.active_tile_card.id]
		)


func _print_full_nine_summary() -> void:
	print("[playtest] --- full 1-9 by bot and layout ---")
	for bot_id: String in BOT_IDS:
		print("[playtest] bot=%s" % bot_id)
		for character_id: String in _layouts:
			var wins := 0
			var runs := 0
			var round_sum := 0.0
			var loss_rounds: Dictionary = {}
			var sizes: Array = []
			for case_data: Dictionary in _cases:
				if str(case_data.get("suite", "")) != "full_nine":
					continue
				if str(case_data.get("character", "")) != character_id:
					continue
				var details: Dictionary = case_data.get("details", {})
				if str(details.get("bot", "fill")) != bot_id:
					continue
				runs += 1
				if sizes.is_empty():
					sizes = details.get("segment_sizes", [])
				if bool(case_data.get("passed", false)):
					wins += 1
					round_sum += float(FULL_RUN_TARGET_ROUND)
				else:
					var reached := int(details.get("reached_round", 0))
					round_sum += float(reached)
					loss_rounds[reached] = int(loss_rounds.get(reached, 0)) + 1
			if runs <= 0:
				continue
			var avg_round := round_sum / float(runs)
			print(
				"[playtest]   %s sizes=%s  %d/%d wins (%.0f%%)  avg round %.1f  loss-by-round %s"
				% [character_id, str(sizes), wins, runs, 100.0 * float(wins) / float(runs), avg_round, str(loss_rounds)]
			)


func _record(
	suite: String,
	character_id: String,
	seed_text: String,
	passed: bool,
	reasons: Array[String],
	details: Dictionary
) -> void:
	if not passed:
		_failed += 1
	_cases.append({
		"suite": suite,
		"character": character_id,
		"seed": seed_text,
		"passed": passed,
		"reasons": reasons,
		"details": details,
	})
	var mark := "PASS" if passed else "FAIL"
	var extra := "" if reasons.is_empty() else " — %s" % ", ".join(reasons)
	if not passed or suite != "starter_fairness":
		print("[playtest] %s %s/%s %s %s%s" % [mark, suite, details.get("bot", "-"), character_id, seed_text, extra])


func _write_report() -> void:
	var payload := {
		"failed": _failed,
		"passed": _cases.size() - _failed,
		"total": _cases.size(),
		"cases": _cases,
	}
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		push_error("PlaytestRunner: could not write %s" % _report_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	print("[playtest] wrote %s (%d failed / %d total)" % [_report_path, _failed, _cases.size()])
	print("[playtest] user data dir: %s" % OS.get_user_data_dir())
