extends Node

## Headless balance playtest. Instantiates a live hex map, skips presentation,
## and writes user://playtest_report.json (or playtest_report_<layout>.json).
##
## godot --headless --path "E:/Godot/game++" res://scenes/debug/playtest_runner.tscn
## Restrict to one layout with `-- --layout=surveyor`.
## Player-only batch: `-- --bot=player --full-count=8` (skips starter/R1 suites).
## Player bot uses Spark on the engine segment, potions, chip placement, and layout plans.
## Surveyor locks a 6–7 hex line through R5. Columnist locks a 7-hex column through R5.
## Surveyor then stays on that 7-hex line until full. Columnist rerolls hard through R4.

const HEX_MAP_SCENE := preload("res://scenes/hex_tile_map.tscn")
const REPORT_PATH := "user://playtest_report.json"
const STARTER_SEED_COUNT := 16
const R1_BOT_SEED_COUNT := 4
const FULL_RUN_SEED_COUNT := 4
const FULL_RUN_TARGET_ROUND := 9
const MERCHANT_STOCK_COUNT := 3
## fill: next empty hex in trigger order. stack: pile Energy and Mult on one line.
## spread: put each new card on the emptiest legal segment.
## player: commit to the largest line, reroll junk, tokens, Transposition.
const BOT_IDS: Array[String] = ["fill", "stack", "spread", "player"]
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
const SEGMENT_SNAPSHOT_ROUNDS: Array[int] = [3, 6, 9]
const MERCHANT_BASE_REROLL_COST := 5
const MAX_MERCHANT_GOLD_REROLLS := 2
const PACK_KEEP_THRESHOLD := 32.0
const SHOP_KEEP_THRESHOLD := 32.0
## Player saves pack rerolls until this round unless the offer cannot be placed at all.
const PLAYER_PACK_REROLL_ROUND := 4
## Gold cards stop being worth an engine slot after this round.
const PLAYER_GOLD_CUTOFF_ROUND := 4
## Pay a merchant token instead of gold at this shop price.
const PLAYER_TOKEN_GOLD_PRICE := 8
const SPARK_PASSIVE_ID := "spark"
const SHOP_GOLD_RESERVE := 8
const MAX_SHOP_BUYS_PER_VISIT := 2
const POTION_SHOP_STOCK := 3
## Cards that often belong off the main engine line.
const OFF_ENGINE_CARD_IDS: Array[String] = [
	"wide_ratio",
	"census_cell",
	"share_load",
	"compact_power",
]
## Layout-specific segment size priorities for engine selection.
const LAYOUT_ENGINE_SIZE_PRIORITY: Dictionary = {
	"surveyor": [7, 6],
	"spiralist": [18, 12, 6],
	"encircler": [18, 12],
	"columnist": [7],
	"converger": [9],
}
## Surveyor and Columnist keep one opening engine line through early rounds.
const SURVEYOR_ENGINE_LOCK_ROUND := 6
const COLUMNIST_ENGINE_LOCK_ROUND := 6
const SURVEYOR_ENGINE_MIN_SIZE := 6
const SURVEYOR_ENGINE_MAX_SIZE := 7
const COLUMNIST_ENGINE_SIZE := 7
const COLUMNIST_EARLY_ROUND := 4

var _map: HexTileMap
var _cases: Array[Dictionary] = []
var _failed := 0
var _active_bot: String = "fill"
var _layouts: Array[String] = []
var _report_path := REPORT_PATH
var _only_bot := ""
var _only_seed := ""
var _full_run_seed_count := FULL_RUN_SEED_COUNT
## Surveyor and Columnist opening engine line. -1 means no lock.
var _locked_engine_segment := -1


func _enter_tree() -> void:
	GameManager.skip_presentation = true


func _ready() -> void:
	_layouts = _parse_layout_filter()
	if _layouts.size() == 1:
		_report_path = "user://playtest_report_%s.json" % _layouts[0]
	print("[playtest] layouts=%s bot=%s seed=%s full_count=%d passives=player_spark" % [
		",".join(_layouts),
		_only_bot if not _only_bot.is_empty() else "all",
		_only_seed if not _only_seed.is_empty() else "all",
		_full_run_seed_count,
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
		elif arg.begins_with("--full-count="):
			_full_run_seed_count = maxi(1, int(arg.substr("--full-count=".length()).strip_edges()))
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
		var character_id := _layouts[0]
		var bots: Array[String] = [_only_bot] if not _only_bot.is_empty() else BOT_IDS
		print("[playtest] focused seed=%s layout=%s bots=%s passives=player_spark" % [
			_only_seed,
			character_id,
			",".join(bots),
		])
		for bot_id: String in bots:
			await _run_one_full_nine(character_id, _only_seed, bot_id)
		_print_full_nine_summary()
		return
	if not _only_bot.is_empty():
		await _run_full_nines()
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
	var bots := _full_nine_bots()
	print("[playtest] full 1-9 bots=%s seeds=%d passives=player_spark" % [",".join(bots), _full_run_seed_count])
	for bot_id: String in bots:
		_active_bot = bot_id
		for character_id: String in _layouts:
			for index in _full_run_seed_count:
				var seed_text := _seed_for("F9", character_id, index)
				await _run_one_full_nine(character_id, seed_text, bot_id)
	_print_full_nine_summary()


func _full_nine_bots() -> Array[String]:
	if _only_bot.is_empty():
		return BOT_IDS.duplicate()
	if _only_bot not in BOT_IDS:
		push_error("PlaytestRunner: unknown bot %s (expected one of %s)" % [_only_bot, str(BOT_IDS)])
		return BOT_IDS.duplicate()
	return [_only_bot]


func _run_one_full_nine(character_id: String, seed_text: String, bot_id: String) -> void:
	_active_bot = bot_id
	print("[playtest] start full_nine/%s %s %s" % [bot_id, character_id, seed_text])
	_begin_run(character_id, seed_text)
	var hand := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
	_place_opening_hand(hand)
	if bot_id == "player":
		_apply_spark_on_engine()

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
			if bot_id == "player":
				_player_use_belt_before_resolve()
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
		var round_entry := {
			"round": round_number,
			"goal": goal,
			"score": score,
			"turns_used": turns_used,
			"gold": GoldManager.amount,
			"cleared": cleared,
			"event": EventManager.get_active_event_name(),
		}
		if round_number in SEGMENT_SNAPSHOT_ROUNDS:
			var snapshot := _segment_contribution_snapshot()
			round_entry["segments"] = snapshot
			_print_segment_snapshot(round_number, snapshot)
		round_log.append(round_entry)
		if not _only_seed.is_empty():
			print(
				"[playtest]   R%d %d/%d turns=%d gold=%d tokens=%d %s"
				% [
					round_number,
					score,
					goal,
					turns_used,
					GoldManager.amount,
					GoldManager.merchant_tokens,
					"clear" if cleared else "fail",
				]
			)
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
			"playtest_passives": ["spark"] if bot_id == "player" else [],
		}
	)


func _draft_and_pick_pack(is_reward: bool, round_number: int, fail_remaining_turns: int) -> TileCard:
	if EventManager.get_runes_pack_size(is_reward) <= 0:
		return null
	if _active_bot == "player":
		return _draft_and_pick_pack_player(is_reward, round_number, fail_remaining_turns)
	var stream_name := RunRng.build_rune_offer_stream_name(
		round_number,
		fail_remaining_turns,
		is_reward,
		0
	)
	var pack := RuneLoot.draw_runes(
		EventManager.get_runes_pack_size(is_reward),
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


func _draft_and_pick_pack_player(
	is_reward: bool,
	round_number: int,
	fail_remaining_turns: int
) -> TileCard:
	var reroll_index := 0
	while true:
		var stream_name := RunRng.build_rune_offer_stream_name(
			round_number,
			fail_remaining_turns,
			is_reward,
			reroll_index
		)
		var pack := RuneLoot.draw_runes(
			EventManager.get_runes_pack_size(is_reward),
			GameManager.tile_cards_pool,
			true,
			RunRng.create_rng(stream_name)
		)
		var best := _pick_best_player_card(pack)
		if not _player_should_reroll_pack(best, is_reward, round_number):
			return best
		if not RerollManager.can_reroll():
			return best
		RerollManager.use_reroll()
		reroll_index += 1
	return null


## Keep a card that belongs on the engine. Reroll more when behind on the round goal.
func _player_should_reroll_pack(best: TileCard, is_reward: bool, round_number: int) -> bool:
	if not RerollManager.can_reroll():
		return false
	if best == null:
		return true
	var keep_threshold := _player_pack_keep_threshold(round_number)
	if _columnist_early_round() and round_number <= 3:
		if best == null or not _can_place_on_locked_column(best):
			return true
		# R1–R3. Hold out for the first Energy or Mult producer on the locked column.
		if not _columnist_locked_has_producer():
			if (
				best.type == TileCard.TileCardType.PRODUCER
				and best.product in [TileCard.Product.SCORE, TileCard.Product.MULTIPLIER]
			):
				return false
			return true
		if best.type != TileCard.TileCardType.PRODUCER:
			return true
		if _card_player_value(best) < keep_threshold * 0.65:
			return true
		return false
	if _columnist_early_round() and round_number == COLUMNIST_EARLY_ROUND:
		if best == null or not _can_place_on_locked_column(best):
			return true
		if _card_player_value(best) < keep_threshold * 0.75:
			return true
		return false
	if _can_place_for_player(best) and _card_player_value(best) >= keep_threshold * 0.5:
		return false
	if is_reward and _can_place_for_player(best):
		return false
	if round_number < PLAYER_PACK_REROLL_ROUND and RerollManager.remaining <= 2:
		var gap_ratio := _round_score_gap_ratio()
		# Columnist spends rerolls freely in R1–R3 instead of hoarding them.
		if not (_is_columnist() and round_number <= 3) and gap_ratio < 0.35:
			return false
	return _card_player_value(best) < keep_threshold or not _can_place_for_player(best)


func _player_pack_keep_threshold(round_number: int) -> float:
	var threshold := PACK_KEEP_THRESHOLD
	threshold -= _round_score_gap_ratio() * 24.0
	if round_number >= 7:
		threshold -= 4.0
	if round_number < PLAYER_PACK_REROLL_ROUND:
		if _columnist_early_round():
			threshold -= 12.0
		else:
			threshold += 8.0
	return maxf(12.0, threshold)


func _round_score_gap_ratio() -> float:
	var goal := maxi(1, GameManager.required_score)
	var gap := maxi(0, goal - GameManager.total_round_score)
	return float(gap) / float(goal)


func _pick_best_playable_card(pack: Array[TileCard]) -> TileCard:
	var best: TileCard = null
	var best_value := -1.0
	for card: TileCard in pack:
		if not _can_bot_place_card(card):
			continue
		var value := _card_keep_value(card)
		if best == null or value > best_value:
			best = card
			best_value = value
	return best


func _pick_best_player_card(pack: Array[TileCard]) -> TileCard:
	var best: TileCard = null
	var best_value := -1.0
	for card: TileCard in pack:
		if not _can_bot_place_card(card):
			continue
		var value := _card_player_value(card)
		# Engine-legal cards beat off-engine filler even when the raw number is close.
		if _can_place_for_player(card):
			value += 25.0
		if _columnist_early_round() and _can_place_on_locked_column(card):
			value += 30.0 + _columnist_engine_balance_bonus(card)
			if GameManager.current_round <= 3 and not _columnist_locked_has_producer():
				if (
					card.type == TileCard.TileCardType.PRODUCER
					and card.product in [TileCard.Product.SCORE, TileCard.Product.MULTIPLIER]
				):
					value += 80.0
		if best == null or value > best_value:
			best = card
			best_value = value
	return best


func _shop_current_round() -> Array[String]:
	if _active_bot == "player":
		return _shop_player_round()
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


func _shop_player_round() -> Array[String]:
	var bought: Array[String] = []
	var stock_reroll_count := 0
	var reroll_cost := MERCHANT_BASE_REROLL_COST
	var gold_rerolls := 0
	while true:
		var stock := _draw_merchant_stock(stock_reroll_count)
		var potion_stock := _draw_merchant_potions(stock_reroll_count)
		var engine_stock := _player_engine_shop_cards(stock)
		engine_stock.sort_custom(func(a: TileCard, b: TileCard) -> bool:
			return _shop_card_score(a) > _shop_card_score(b)
		)
		var potion_pick := _pick_best_shop_potion(potion_stock)
		var buys_this_visit := 0
		if potion_pick != null and _buy_shop_potion(potion_pick, bought):
			buys_this_visit += 1
		for card: TileCard in engine_stock:
			if buys_this_visit >= MAX_SHOP_BUYS_PER_VISIT:
				break
			if not _can_afford_shop_purchase(card):
				continue
			if _buy_shop_card(card, bought):
				buys_this_visit += 1
				_apply_spark_on_engine()
		if buys_this_visit > 0:
			return bought
		if (
			gold_rerolls >= MAX_MERCHANT_GOLD_REROLLS
			or not GoldManager.can_afford(reroll_cost)
		):
			# Leave rather than stuffing a tiny segment with leftover shop junk.
			return bought
		GoldManager.remove(reroll_cost)
		stock_reroll_count += 1
		reroll_cost += 1
		gold_rerolls += 1
	return bought


func _shop_card_score(card: TileCard) -> float:
	if card == null:
		return 0.0
	var price := maxf(1.0, float(card.get_shop_price()))
	return _card_player_value(card) / price


func _can_afford_shop_purchase(card: TileCard) -> bool:
	var price := card.get_shop_price()
	var token_cost := GoldManager.MERCHANT_TOKEN_COST
	if _player_wants_to_pay_tokens(card, price) and GoldManager.can_afford_tokens(token_cost):
		return true
	if GoldManager.can_afford(price):
		return GoldManager.amount - price >= SHOP_GOLD_RESERVE or price <= 4
	if GoldManager.can_afford_tokens(token_cost):
		return true
	return false


func _draw_merchant_potions(stock_reroll_count: int) -> Array[Potion]:
	var stream_name := "merchant_potions:r%d:e%d" % [GameManager.current_round, stock_reroll_count]
	return PotionCatalog.draw_unique(
		POTION_SHOP_STOCK,
		RunRng.create_rng(stream_name)
	)


func _pick_best_shop_potion(stock: Array[Potion]) -> Potion:
	var best: Potion = null
	var best_value := -1.0
	for potion: Potion in stock:
		if potion == null:
			continue
		var value := _potion_player_value(potion)
		var price := maxf(1.0, float(potion.get_shop_price()))
		value /= price
		if best == null or value > best_value:
			best = potion
			best_value = value
	if best == null or best_value < 0.35:
		return null
	return best


func _buy_shop_potion(potion: Potion, bought: Array[String]) -> bool:
	if potion == null or not PotionManager.can_add():
		return false
	var price := potion.get_shop_price()
	var token_cost := GoldManager.MERCHANT_TOKEN_COST
	if price >= PLAYER_TOKEN_GOLD_PRICE and GoldManager.can_afford_tokens(token_cost):
		if not GoldManager.spend_tokens(token_cost):
			return false
		bought.append("%s:potion:%s@token" % [GameManager.current_round, potion.id])
	elif GoldManager.can_afford(price):
		if GoldManager.amount - price < SHOP_GOLD_RESERVE:
			return false
		GoldManager.remove(price)
		bought.append("%s:potion:%s@%d" % [GameManager.current_round, potion.id, price])
	elif GoldManager.can_afford_tokens(token_cost):
		if not GoldManager.spend_tokens(token_cost):
			return false
		bought.append("%s:potion:%s@token" % [GameManager.current_round, potion.id])
	else:
		return false
	return PotionManager.add_potion(potion)


func _player_engine_shop_cards(stock: Array[TileCard]) -> Array[TileCard]:
	var picks: Array[TileCard] = []
	for card: TileCard in stock:
		if not _can_bot_place_card(card):
			continue
		if not _can_place_for_player(card) and card.id != "transposition":
			continue
		if _card_player_value(card) < SHOP_KEEP_THRESHOLD and card.id != "transposition":
			continue
		picks.append(card)
	return picks


func _draw_merchant_stock(stock_reroll_count: int) -> Array[TileCard]:
	var stream_name := RunRng.build_merchant_stream_name(GameManager.current_round, stock_reroll_count)
	var stock := RuneLoot.draw_runes(
		MERCHANT_STOCK_COUNT,
		GameManager.tile_cards_pool,
		true,
		RunRng.create_rng(stream_name)
	)
	stock.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return _card_keep_value(a) > _card_keep_value(b)
	)
	return stock


func _buy_shop_card(card: TileCard, bought: Array[String]) -> bool:
	if not _can_bot_place_card(card):
		return false
	var price := card.get_shop_price()
	var token_cost := GoldManager.MERCHANT_TOKEN_COST
	var pay_tokens := _player_wants_to_pay_tokens(card, price)
	if pay_tokens and GoldManager.can_afford_tokens(token_cost):
		if not GoldManager.spend_tokens(token_cost):
			return false
		bought.append("%s:%s@token" % [GameManager.current_round, card.id])
	elif GoldManager.can_afford(price):
		GoldManager.remove(price)
		bought.append("%s:%s@%d" % [GameManager.current_round, card.id, price])
	elif GoldManager.can_afford_tokens(token_cost):
		if not GoldManager.spend_tokens(token_cost):
			return false
		bought.append("%s:%s@token" % [GameManager.current_round, card.id])
	else:
		return false
	_place_one_card(card)
	return true


## Spend tokens on rares and expensive stock. Pay gold for cheap commons so tokens last.
func _player_wants_to_pay_tokens(card: TileCard, price: int) -> bool:
	if card.rarity != TileCard.TileCardRarity.COMMON:
		return true
	return price >= PLAYER_TOKEN_GOLD_PRICE


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


## Score a card for packs and shop using chip previews and engine balance.
func _card_player_value(card: TileCard) -> float:
	if card == null:
		return 0.0
	if card.id == "transposition":
		return 55.0 if _find_player_swap().size() == 2 else 0.0
	if card.type == TileCard.TileCardType.UTILITY:
		return 0.0
	if _prefers_off_engine(card):
		return _best_off_engine_preview_value(card)
	var engine := _player_engine_index()
	var energy := _segment_product_count(engine, TileCard.Product.SCORE)
	var mult := _segment_product_count(engine, TileCard.Product.MULTIPLIER)
	var value := 8.0
	match card.product:
		TileCard.Product.MULTIPLIER:
			value = 45.0 + float(card.base_production_amount) * 20.0
			if energy > 0 and mult <= energy:
				value += 20.0
		TileCard.Product.SCORE:
			value = 18.0 + float(card.base_production_amount)
			if mult > 0 and energy <= mult:
				value += 16.0
		TileCard.Product.GOLD:
			if GameManager.current_round >= PLAYER_GOLD_CUTOFF_ROUND:
				value = 4.0
			else:
				value = 14.0 + float(card.base_production_amount) * 6.0
		_:
			if card.type == TileCard.TileCardType.SUPPORT:
				value = 28.0 + float(card.base_production_amount)
				if energy + mult >= 2:
					value += 10.0
	if card.rarity == TileCard.TileCardRarity.RARE:
		value += 12.0
	elif card.rarity == TileCard.TileCardRarity.UNCOMMON:
		value += 6.0
	value += _best_engine_preview_value(card) * 0.35
	return value


func _prefers_off_engine(card: TileCard) -> bool:
	return card != null and card.id in OFF_ENGINE_CARD_IDS


func _best_engine_preview_value(card: TileCard) -> float:
	var best := 0.0
	var engine := _player_engine_index()
	if engine < 0:
		return best
	for hex: Hex in _empty_hexes_in_segment(engine):
		if not card.can_place_on_tile(hex):
			continue
		best = maxf(best, _chip_numeric_value(card.get_board_chip(hex)))
	return best


func _best_off_engine_preview_value(card: TileCard) -> float:
	var best := 0.0
	for segment_index: int in _off_engine_segment_rank(card):
		for hex: Hex in _empty_hexes_in_segment(segment_index):
			if not card.can_place_on_tile(hex):
				continue
			var value := _chip_numeric_value(card.get_board_chip(hex))
			if card.id == "wide_ratio":
				value += 18.0
			elif card.id == "share_load" and segment_index + 1 == _player_engine_index():
				value += 24.0
			elif card.id == "compact_power" and _map.get_segment_size(segment_index) <= 7:
				value += 16.0
			elif card.id == "census_cell":
				value += 10.0
			best = maxf(best, value)
	return best


func _chip_numeric_value(chip: Dictionary) -> float:
	if chip.is_empty():
		return 0.0
	if int(chip.get("mode", TileCard.BoardChipMode.HIDDEN)) == TileCard.BoardChipMode.HIDDEN:
		return 0.0
	var text := str(chip.get("text", "0")).strip_edges()
	if text.is_empty():
		return 0.0
	if text.is_valid_float():
		return float(text)
	return 0.0


func _layout_segment_priority(segment_index: int) -> float:
	if GameManager.selected_character == null:
		return float(_map.get_segment_size(segment_index)) / 20.0
	var priorities: Array = LAYOUT_ENGINE_SIZE_PRIORITY.get(
		GameManager.selected_character.id,
		[]
	)
	var size := _map.get_segment_size(segment_index)
	for i in priorities.size():
		if int(priorities[i]) == size:
			return float(priorities.size() - i) * 2.0
	return float(size) / 20.0


func _segment_engine_rating(segment_index: int) -> float:
	var energy := _map.get_segment_turn_score(segment_index)
	var multiplier := _map.get_segment_turn_multiplier(segment_index)
	var contribution := float(
		GameManager.compute_segment_turn_contribution(segment_index, energy, multiplier)
	)
	var cards := float(_segment_card_count(segment_index))
	var producers := float(
		_segment_product_count(segment_index, TileCard.Product.SCORE)
		+ _segment_product_count(segment_index, TileCard.Product.MULTIPLIER)
	)
	var commitment := float(maxi(0, _segment_card_count(segment_index) - 1)) * 35.0
	var rating := (
		contribution
		+ cards * 8.0
		+ producers * 12.0
		+ commitment
		+ _layout_segment_priority(segment_index) * 100.0
	)
	if _engine_lock_active():
		if segment_index == _locked_engine_segment:
			rating += 100000.0
		elif segment_index in _candidate_engine_segments():
			rating -= 1000.0
		else:
			rating -= 5000.0
	elif _uses_engine_lock() and segment_index == _locked_engine_segment:
		rating += 120.0
	if _is_surveyor() and segment_index == _locked_engine_segment:
		rating += 200.0
	return rating


func _is_surveyor() -> bool:
	return GameManager.selected_character != null and GameManager.selected_character.id == "surveyor"


func _is_columnist() -> bool:
	return GameManager.selected_character != null and GameManager.selected_character.id == "columnist"


func _columnist_early_round() -> bool:
	return _is_columnist() and GameManager.current_round <= COLUMNIST_EARLY_ROUND


func _can_place_on_locked_column(card: TileCard) -> bool:
	if card == null or card.type == TileCard.TileCardType.UTILITY:
		return false
	if _locked_engine_segment < 0:
		return _can_place_for_player(card)
	return _can_place_on_segment(card, _locked_engine_segment)


func _columnist_engine_balance_bonus(card: TileCard) -> float:
	if _locked_engine_segment < 0:
		return 0.0
	var energy := _segment_product_count(_locked_engine_segment, TileCard.Product.SCORE)
	var mult := _segment_product_count(_locked_engine_segment, TileCard.Product.MULTIPLIER)
	match card.product:
		TileCard.Product.MULTIPLIER:
			if energy > 0 and mult <= energy:
				return 24.0
		TileCard.Product.SCORE:
			if mult > 0 and energy <= mult:
				return 24.0
	return 8.0


func _columnist_locked_has_producer() -> bool:
	if _locked_engine_segment < 0:
		return false
	for hex: Hex in _map.get_hexes_in_segment(_locked_engine_segment):
		var card := hex.active_tile_card
		if card == null or card.type != TileCard.TileCardType.PRODUCER:
			continue
		if card.product in [TileCard.Product.SCORE, TileCard.Product.MULTIPLIER]:
			return true
	return false


## Locked opening line for Surveyor and Columnist. Surveyor keeps this segment all run.
func _player_primary_segment() -> int:
	if _uses_engine_lock() and _locked_engine_segment >= 0:
		if _is_surveyor():
			return _locked_engine_segment
		if _engine_lock_active() or _is_columnist():
			return _locked_engine_segment
	var rank := _player_engine_rank()
	return rank[0] if not rank.is_empty() else -1


func _surveyor_primary_has_room() -> bool:
	if not _is_surveyor() or _locked_engine_segment < 0:
		return false
	return not _empty_hexes_in_segment(_locked_engine_segment).is_empty()


func _player_spill_segment_rank(primary: int) -> Array[int]:
	if _is_surveyor():
		var ranked: Array[int] = []
		if primary >= 0:
			ranked.append(primary)
		for index: int in _candidate_engine_segments():
			if index != primary:
				ranked.append(index)
		return ranked
	return _player_engine_rank()


func _should_drink_borrowed_time(gap: int) -> bool:
	if gap <= 0 or GameManager.remaining_turns > 1:
		return false
	var goal := maxi(1, GameManager.required_score)
	var near_miss := maxi(50, int(float(goal) * 0.08))
	if gap <= near_miss:
		return true
	if _columnist_early_round() and GameManager.current_round == COLUMNIST_EARLY_ROUND:
		return gap <= maxi(120, int(float(goal) * 0.12))
	return false


func _uses_engine_lock() -> bool:
	if _active_bot != "player" or GameManager.selected_character == null:
		return false
	var character_id := GameManager.selected_character.id
	return character_id == "surveyor" or character_id == "columnist"


func _engine_lock_unlock_round() -> int:
	if GameManager.selected_character == null:
		return 999
	match GameManager.selected_character.id:
		"surveyor":
			return SURVEYOR_ENGINE_LOCK_ROUND
		"columnist":
			return COLUMNIST_ENGINE_LOCK_ROUND
		_:
			return 999


func _engine_lock_active() -> bool:
	return (
		_uses_engine_lock()
		and _locked_engine_segment >= 0
		and GameManager.current_round < _engine_lock_unlock_round()
	)


func _candidate_engine_segments() -> Array[int]:
	var candidates: Array[int] = []
	if _map == null or GameManager.selected_character == null:
		return candidates
	for index in _map.get_segment_count():
		var size := _map.get_segment_size(index)
		match GameManager.selected_character.id:
			"surveyor":
				if size >= SURVEYOR_ENGINE_MIN_SIZE and size <= SURVEYOR_ENGINE_MAX_SIZE:
					candidates.append(index)
			"columnist":
				if size >= COLUMNIST_ENGINE_SIZE:
					candidates.append(index)
			_:
				pass
	return candidates


## Pick the opening engine line before the first card lands.
func _pick_layout_opening_engine() -> int:
	var candidates := _candidate_engine_segments()
	if candidates.is_empty():
		return _largest_segment_index()
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var cards_a := _segment_card_count(a)
		var cards_b := _segment_card_count(b)
		if cards_a != cards_b:
			return cards_a > cards_b
		var size_a := _map.get_segment_size(a)
		var size_b := _map.get_segment_size(b)
		if size_a != size_b:
			return size_a > size_b
		return a < b
	)
	return candidates[0]


func _init_layout_engine_lock() -> void:
	_locked_engine_segment = -1
	if not _uses_engine_lock():
		return
	_locked_engine_segment = _pick_layout_opening_engine()


func _maybe_relock_engine_from_board() -> void:
	if not _uses_engine_lock():
		return
	var best := -1
	var best_cards := 0
	for index: int in _candidate_engine_segments():
		var cards := _segment_card_count(index)
		if cards <= 0:
			continue
		if cards > best_cards:
			best_cards = cards
			best = index
		elif cards == best_cards and best >= 0:
			if _map.get_segment_size(index) > _map.get_segment_size(best):
				best = index
			elif _map.get_segment_size(index) == _map.get_segment_size(best) and index < best:
				best = index
	if best >= 0 and _engine_lock_active():
		_locked_engine_segment = best


func _apply_spark_on_engine() -> void:
	if _active_bot != "player":
		return
	var engine := _player_primary_segment()
	if engine < 0:
		engine = _player_engine_index()
	if engine < 0:
		GameManager.bind_segment_passives_for_debug({})
		return
	var spark := MetaProgressionManager.get_passive_by_id(SPARK_PASSIVE_ID)
	if spark == null:
		GameManager.bind_segment_passives_for_debug({})
		return
	GameManager.bind_segment_passives_for_debug({engine: [spark]})


func _can_place_for_player(card: TileCard) -> bool:
	if card == null or card.type == TileCard.TileCardType.UTILITY:
		return false
	if _prefers_off_engine(card):
		return _can_place_off_engine(card)
	return _can_place_on_engine(card)


func _can_place_off_engine(card: TileCard) -> bool:
	for segment_index: int in _off_engine_segment_rank(card):
		if _can_place_on_segment(card, segment_index):
			return true
	return false


func _off_engine_segment_rank(card: TileCard) -> Array[int]:
	var ranked: Array[int] = []
	for index in _map.get_segment_count():
		ranked.append(index)
	var engine := _player_engine_index()
	match card.id:
		"compact_power":
			ranked.sort_custom(func(a: int, b: int) -> bool:
				var size_a := _map.get_segment_size(a)
				var size_b := _map.get_segment_size(b)
				if size_a <= 7 and size_b > 7:
					return true
				if size_b <= 7 and size_a > 7:
					return false
				if size_a != size_b:
					return size_a < size_b
				return a < b
			)
		"wide_ratio":
			ranked.sort_custom(func(a: int, b: int) -> bool:
				if a == engine:
					return false
				if b == engine:
					return true
				var count_a := _segment_card_count(a)
				var count_b := _segment_card_count(b)
				if count_a != count_b:
					return count_a < count_b
				return _map.get_segment_size(a) < _map.get_segment_size(b)
			)
		"share_load":
			ranked.sort_custom(func(a: int, b: int) -> bool:
				var feeds_engine_a := a + 1 == engine
				var feeds_engine_b := b + 1 == engine
				if feeds_engine_a != feeds_engine_b:
					return feeds_engine_a
				return _segment_engine_rating(a) > _segment_engine_rating(b)
			)
		_:
			ranked.sort_custom(func(a: int, b: int) -> bool:
				if a == engine:
					return false
				if b == engine:
					return true
				return _map.get_segment_size(a) < _map.get_segment_size(b)
			)
	return ranked


func _placement_score(card: TileCard, hex: Hex, segment_index: int) -> float:
	var score := _chip_numeric_value(card.get_board_chip(hex))
	score += _placement_trigger_bonus(card, hex, segment_index)
	var primary := _player_primary_segment()
	if _is_surveyor() and primary >= 0 and segment_index != primary:
		if _surveyor_primary_has_room():
			score -= 800.0
	if segment_index == primary or segment_index == _player_engine_index():
		score += 20.0
	elif _prefers_off_engine(card):
		score += 12.0
	return score


func _placement_trigger_bonus(card: TileCard, hex: Hex, segment_index: int) -> float:
	var hexes := _map.get_hexes_in_segment(segment_index)
	var order_index := hexes.find(hex)
	if order_index < 0:
		return 0.0
	var segment_len := maxi(1, hexes.size())
	var early_bias := float(segment_len - order_index) / float(segment_len)
	match card.product:
		TileCard.Product.MULTIPLIER:
			return early_bias * 18.0
		TileCard.Product.SCORE:
			return float(order_index) / float(segment_len) * 12.0
		_:
			if card.type == TileCard.TileCardType.SUPPORT:
				return early_bias * 10.0
	return 0.0


func _place_player_card(card: TileCard) -> bool:
	if _prefers_off_engine(card):
		return _place_best_on_segments(card, _off_engine_segment_rank(card))
	var primary := _player_primary_segment()
	var rank := _player_spill_segment_rank(primary)
	if rank.is_empty():
		return false
	# Fill the primary line until it is full, then spill to layout-approved segments only.
	if primary >= 0 and not _empty_hexes_in_segment(primary).is_empty():
		if _place_best_on_segments(card, [primary]):
			_maybe_relock_engine_from_board()
			return true
	var placed := _place_best_on_segments(card, rank)
	if placed:
		_maybe_relock_engine_from_board()
	return placed


func _place_best_on_segments(card: TileCard, ranked_segments: Array[int]) -> bool:
	var best_hex: Hex = null
	var best_score := -1.0
	for segment_index: int in ranked_segments:
		for hex: Hex in _empty_hexes_in_segment(segment_index):
			if not card.can_place_on_tile(hex):
				continue
			var score := _placement_score(card, hex, segment_index)
			if best_hex == null or score > best_score:
				best_hex = hex
				best_score = score
	if best_hex == null:
		return false
	best_hex.place_tile_card(card)
	return true


func _potion_player_value(potion: Potion) -> float:
	if potion == null:
		return 0.0
	var gap := maxi(0, GameManager.required_score - GameManager.total_round_score)
	match potion.effect_type:
		Potion.EffectType.BORROWED_TIME:
			if gap > 0 and GameManager.remaining_turns <= 1:
				return 90.0 + float(gap) / 500.0
			if _columnist_early_round():
				return 22.0
			return 4.0
		Potion.EffectType.EMPOWER, Potion.EffectType.ECHO:
			return 48.0 if _engine_producer_hex() != null else 8.0
		Potion.EffectType.WARD:
			return 24.0 if _engine_producer_hex() != null else 6.0
		Potion.EffectType.NEXT_TRIGGER_ENERGY, Potion.EffectType.NEXT_TRIGGER_MULT:
			return 40.0 if _engine_producer_hex() != null else 8.0
		Potion.EffectType.FORWARD_GIFT, Potion.EffectType.MINT_SIP:
			return 30.0 if _engine_producer_hex() != null else 5.0
		Potion.EffectType.FREE_REROLL:
			return 28.0 if RerollManager.remaining <= 1 else 14.0
		Potion.EffectType.REWRITE_OMEN:
			if EventManager.get_next_event_round() == -1:
				return 0.0
			return 26.0
		Potion.EffectType.OPENING_ROUND, Potion.EffectType.CLOSING_ROUND:
			return 36.0 if _engine_producer_hex() != null else 10.0
		Potion.EffectType.GOLD_DROP:
			return 14.0 if GameManager.current_round <= 3 else 6.0
		Potion.EffectType.POTION_PACK:
			return 18.0 if PotionManager.empty_slot_count() >= 2 else 8.0
		_:
			return 6.0


func _engine_producer_hex() -> Hex:
	var engine := _player_engine_index()
	if engine < 0:
		return null
	for hex: Hex in _map.get_hexes_in_segment(engine):
		var card := hex.active_tile_card
		if card != null and card.type == TileCard.TileCardType.PRODUCER:
			return hex
	return null


func _player_use_belt_before_resolve() -> void:
	if not PotionManager.can_drink_now():
		return
	var gap := maxi(0, GameManager.required_score - GameManager.total_round_score)
	for i in PotionManager.BELT_SIZE:
		var potion := PotionManager.belt[i]
		if potion == null:
			continue
		if potion.effect_type == Potion.EffectType.BORROWED_TIME:
			if _should_drink_borrowed_time(gap):
				PotionManager.headless_use_slot(i)
				return
	for i in PotionManager.BELT_SIZE:
		var potion := PotionManager.belt[i]
		if potion == null:
			continue
		if potion.effect_type in [Potion.EffectType.OPENING_ROUND, Potion.EffectType.CLOSING_ROUND]:
			if _engine_producer_hex() != null and gap > int(float(GameManager.required_score) * 0.15):
				PotionManager.headless_use_slot(i)
				return
	for i in PotionManager.BELT_SIZE:
		var potion := PotionManager.belt[i]
		if potion == null:
			continue
		if potion.effect_type in [
			Potion.EffectType.EMPOWER,
			Potion.EffectType.ECHO,
			Potion.EffectType.NEXT_TRIGGER_ENERGY,
			Potion.EffectType.NEXT_TRIGGER_MULT,
			Potion.EffectType.FORWARD_GIFT,
			Potion.EffectType.MINT_SIP,
			Potion.EffectType.WARD,
		]:
			var target := _best_potion_target_hex(potion)
			if target != null and gap > 0:
				PotionManager.headless_use_slot(i, target)
				return
	for i in PotionManager.BELT_SIZE:
		var potion := PotionManager.belt[i]
		if potion == null:
			continue
		if potion.effect_type == Potion.EffectType.REWRITE_OMEN:
			if EventManager.get_next_event_round() != -1 and GameManager.current_round >= 4:
				PotionManager.headless_use_slot(i)
				return


func _best_potion_target_hex(potion: Potion) -> Hex:
	var engine_hex := _engine_producer_hex()
	if engine_hex != null:
		return engine_hex
	var engine := _player_engine_index()
	if engine < 0:
		return null
	for hex: Hex in _map.get_hexes_in_segment(engine):
		if hex.active_tile_card != null:
			return hex
	return null


func _can_bot_place_card(card: TileCard) -> bool:
	if card == null:
		return false
	if card.type == TileCard.TileCardType.UTILITY:
		# Player bot can swap two occupied tiles. Other utilities stay too fiddly.
		if _active_bot == "player" and card.id == "transposition":
			return _find_player_swap().size() == 2
		return false
	if not card.is_legal_for_layout(GameManager.selected_character):
		return false
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.is_placement_blocked() or hex.active_tile_card != null:
			continue
		if card.can_place_on_tile(hex):
			return true
	return false


func _place_opening_hand(hand: Array[TileCard]) -> void:
	match _active_bot:
		"player":
			_init_layout_engine_lock()
			for card: TileCard in _order_hand_for_line(hand):
				_place_one_card(card)
			return
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
	if _active_bot == "player" and card.id == "transposition":
		var played := _play_transposition()
		if played:
			_apply_spark_on_engine()
		return played
	match _active_bot:
		"player":
			if _place_player_card(card):
				_apply_spark_on_engine()
				return true
			if card.has_placement_restriction():
				if _place_first_legal_empty(card):
					_apply_spark_on_engine()
					return true
			return false
		"stack":
			if _place_on_preferred_segments(card, _stack_segment_rank()):
				return true
		"spread":
			if _place_on_preferred_segments(card, _spread_segment_rank()):
				return true
	return _place_first_legal_empty(card)


func _place_first_legal_empty(card: TileCard) -> bool:
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.is_placement_blocked() or hex.active_tile_card != null:
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


## Last turn's Energy, Mult, and E×M contribution per segment.
func _segment_contribution_snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _map == null:
		return rows
	for index in _map.get_segment_count():
		var energy := _map.get_segment_turn_score(index)
		var multiplier := _map.get_segment_turn_multiplier(index)
		rows.append({
			"index": index,
			"size": _map.get_segment_size(index),
			"energy": energy,
			"mult": multiplier,
			"contribution": GameManager.compute_segment_turn_contribution(index, energy, multiplier),
		})
	return rows


func _print_segment_snapshot(round_number: int, snapshot: Array[Dictionary]) -> void:
	var parts: PackedStringArray = []
	for row: Dictionary in snapshot:
		parts.append(
			"s%d(n=%d E=%d M=%s C=%d)"
			% [
				int(row.get("index", 0)),
				int(row.get("size", 0)),
				int(row.get("energy", 0)),
				CountingNumber.format_mult(float(row.get("mult", 1.0))),
				int(row.get("contribution", 0)),
			]
		)
	print("[playtest]   R%d segments %s" % [round_number, " ".join(parts)])


func _largest_segment_index() -> int:
	if _map == null:
		return -1
	var best := -1
	var best_size := -1
	for index in _map.get_segment_count():
		var segment_size := _map.get_segment_size(index)
		if segment_size > best_size:
			best_size = segment_size
			best = index
	return best


func _player_engine_index() -> int:
	if _map == null:
		return -1
	if _uses_engine_lock() and _locked_engine_segment >= 0:
		if _is_surveyor() and _surveyor_primary_has_room():
			return _locked_engine_segment
		if _engine_lock_active():
			return _locked_engine_segment
	var best := -1
	var best_rating := -1.0
	for index in _map.get_segment_count():
		var rating := _segment_engine_rating(index)
		if rating > best_rating:
			best_rating = rating
			best = index
	if best < 0:
		return _largest_segment_index()
	return best


## Highest-rated line first. Tie-break with layout size priorities.
func _player_engine_rank() -> Array[int]:
	if _uses_engine_lock() and _locked_engine_segment >= 0:
		if _is_surveyor() or _engine_lock_active():
			var locked_rank: Array[int] = [_locked_engine_segment]
			for index: int in _candidate_engine_segments():
				if index != _locked_engine_segment:
					locked_rank.append(index)
			return locked_rank
	var ranked: Array[int] = []
	for index in _map.get_segment_count():
		ranked.append(index)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var rating_a := _segment_engine_rating(a)
		var rating_b := _segment_engine_rating(b)
		if rating_a != rating_b:
			return rating_a > rating_b
		return a < b
	)
	return ranked


func _can_place_on_engine(card: TileCard) -> bool:
	if card == null or card.type == TileCard.TileCardType.UTILITY:
		return false
	var engine := _player_engine_index()
	if engine < 0:
		return false
	if not _empty_hexes_in_segment(engine).is_empty():
		return _can_place_on_segment(card, engine)
	var next_sizes := _player_spill_segment_rank(_player_primary_segment())
	for segment_index: int in next_sizes:
		if segment_index == engine:
			continue
		if _is_surveyor():
			if _can_place_on_segment(card, segment_index):
				return true
			continue
		if _map.get_segment_size(segment_index) < 6:
			break
		if _can_place_on_segment(card, segment_index):
			return true
	return false


func _can_place_on_segment(card: TileCard, segment_index: int) -> bool:
	for hex: Hex in _empty_hexes_in_segment(segment_index):
		if card.can_place_on_tile(hex):
			return true
	return false


## Pull a stronger card onto the engine or fix trigger order with Transposition.
func _find_player_swap() -> Array[Hex]:
	var engine := _player_engine_index()
	if engine < 0:
		return []
	var occupied: Array[Hex] = []
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.active_tile_card != null:
			occupied.append(hex)
	var best_pair: Array[Hex] = []
	var best_score := 0.0
	for i in occupied.size():
		for j in range(i + 1, occupied.size()):
			var a: Hex = occupied[i]
			var b: Hex = occupied[j]
			var score := _score_swap_pair(a, b, engine)
			if score > best_score:
				best_score = score
				best_pair = [a, b]
	if best_score <= 0.0:
		return []
	return best_pair


func _score_swap_pair(a: Hex, b: Hex, engine: int) -> float:
	var seg_a := _map.get_segment_index(a.coordinates)
	var seg_b := _map.get_segment_index(b.coordinates)
	var str_a := _hex_strength(a)
	var str_b := _hex_strength(b)
	var gain := 0.0
	if seg_a == engine and str_b > str_a + 4.0:
		gain += str_b - str_a
	if seg_b == engine and str_a > str_b + 4.0:
		gain += str_a - str_b
	if seg_a == engine and seg_b == engine:
		gain += _trigger_order_swap_gain(a, b)
	return gain


func _hex_strength(hex: Hex) -> float:
	var card := hex.active_tile_card
	if card == null:
		return 0.0
	return _chip_numeric_value(card.get_board_chip(hex)) + float(_player_swap_weight(card)) * 8.0


func _trigger_order_swap_gain(a: Hex, b: Hex) -> float:
	var segment_index := _map.get_segment_index(a.coordinates)
	var hexes := _map.get_hexes_in_segment(segment_index)
	var order_a := hexes.find(a)
	var order_b := hexes.find(b)
	if order_a < 0 or order_b < 0:
		return 0.0
	var card_a := a.active_tile_card
	var card_b := b.active_tile_card
	if card_a == null or card_b == null:
		return 0.0
	var gain := 0.0
	if card_a.product == TileCard.Product.MULTIPLIER and order_a > order_b:
		gain += 12.0
	if card_b.product == TileCard.Product.MULTIPLIER and order_b > order_a:
		gain += 12.0
	if card_a.type == TileCard.TileCardType.SUPPORT and order_a > order_b:
		gain += 8.0
	if card_b.type == TileCard.TileCardType.SUPPORT and order_b > order_a:
		gain += 8.0
	return gain


func _player_swap_weight(card: TileCard) -> int:
	if card == null:
		return 0
	match card.product:
		TileCard.Product.MULTIPLIER:
			return 4
		TileCard.Product.SCORE:
			return 3
		TileCard.Product.GOLD:
			return 0
		_:
			if card.type == TileCard.TileCardType.SUPPORT:
				return 2
			return 1


func _play_transposition() -> bool:
	var pair := _find_player_swap()
	if pair.size() != 2:
		return false
	_map.swap_placed_tile_cards(pair[0], pair[1])
	return true


func _begin_run(character_id: String, seed_text: String) -> void:
	GameManager.skip_presentation = true
	GameManager.selected_character = PlayerCharacter.get_character_by_id(character_id)
	GameManager.selected_difficulty = Difficulty.Level.LEVEL_0
	RunRng.begin_new_run(seed_text)
	GameManager.reset_for_new_run()
	GoldManager.set_run_starting_gold(GameManager.selected_difficulty)
	RerollManager.reset_for_new_run()
	EventManager.init_run()
	_clear_board()
	_map.generate_terrain()
	_map.apply_run_start_randomization()
	_locked_engine_segment = -1
	# Player bot Spark is applied after the opening hand. Other bots stay passive-free.
	if _active_bot != "player":
		GameManager.bind_segment_passives_for_debug({})
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
		if hex.active_tile_card == null and not hex.is_placement_blocked():
			return hex
	return null


func _two_hexes_in_same_segment() -> Array[Hex]:
	var found: Array[Hex] = []
	var segment_index := -1
	for hex: Hex in _map.get_hexes_in_trigger_order():
		if hex.is_placement_blocked():
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
		if hex.active_tile_card != null or hex.is_placement_blocked():
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
	for bot_id: String in _full_nine_bots():
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
