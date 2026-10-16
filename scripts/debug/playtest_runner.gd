extends Node

## Headless playtests. Plays seeded runs through the real day flow (Hours, leftover Hours,
## End Day, reward pick, merchant, events) with a bot and writes user://playtest_report.json.
##
## godot --headless --path . res://scenes/debug/playtest_runner.tscn -- [flags]
##   --runs=N          Seeds per chef (default 8). Every chef plays the same seeds.
##   --chef=<id>       One chef: sous_chef, sommelier or gourmet_restaurant.
##   --seed=<text>     Play one seed. --repeat=N plays it N times to check determinism.
##   --difficulty=N    Difficulty level index (default 0).
##   --power           Days have no goal and always play every Hour. Reports raw score per day.
##   --fuzz            Chaos bot: random legal actions. Fails on invariants and script errors.
##   --no-condiments   The bot never buys or drinks condiments.
##   --no-overplay     Cards only go on empty spots (no merging or replacing). A/B baseline.
##   --check-sim       Compare full state before and after every what-if Hour.
##   --verbose         One line per day.
##   --out=<path>      Report path (default user://playtest_report.json).
##
## The human bot previews every option with a what-if Hour (PlaytestSim), so it plays each
## chef's speciality through the real rules. Compare two reports with
## scripts/debug/compare_playtest_reports.py and list picks with analyze_pick_report.py.

const HEX_MAP_SCENE := preload("res://scenes/hex_tile_map.tscn")
const SCRIPT_ERROR_TRACKER := preload("res://scripts/debug/playtest_script_error_tracker.gd")
const PLAYTEST_SIM := preload("res://scripts/debug/playtest/playtest_sim.gd")
const HUMAN_POLICY := preload("res://scripts/debug/playtest/human_policy.gd")
const CHAOS_POLICY := preload("res://scripts/debug/playtest/chaos_policy.gd")
const REPORT_PATH := "user://playtest_report.json"
const STARTER_SEED_COUNT := 16
const DEFAULT_RUN_COUNT := 8
## Safety stops for a run or Hour that never finishes.
const MAX_HOURS_PER_RUN := 120
const MAX_ACTIONS_PER_HOUR := 30


## One merchant visit with the same shelves, prices and reroll costs as the Merchant panel.
class MerchantVisit:
	extends RefCounted

	var cards: Array[TileCard] = []
	var staff: Array[StaffCard] = []
	var condiments: Array[Condiment] = []
	var reroll_cost := Merchant.BASE_REROLL_COST
	var _runner: Node
	var _reroll_count := 0

	func _init(runner: Node) -> void:
		_runner = runner
		_roll_stock()

	func _roll_stock() -> void:
		cards = Merchant.draw_tile_card_stock(_reroll_count)
		staff = Merchant.draw_staff_stock(_reroll_count, StaffManager.owned_ids())
		condiments = Merchant.draw_condiment_stock(_reroll_count)

	func price_of(item: Resource) -> int:
		return item.get_shop_price()

	func buy_card(index: int) -> bool:
		var card := cards[index]
		if card == null or not EconomyManager.can_afford(price_of(card)):
			return false
		var price := price_of(card)
		EconomyManager.remove(price)
		cards[index] = null
		_runner.note_buy("", card.id, price)
		EventBus.tile_card_selected.emit(card)
		return true

	## Seats the new staff member in the first free slot, as the shop does, then moves it.
	func buy_staff(index: int, slot: int) -> bool:
		var member := staff[index]
		if member == null or not member.get_purchase_block_reason().is_empty():
			return false
		var price := price_of(member)
		if not EconomyManager.can_afford(price):
			return false
		EconomyManager.remove(price)
		staff[index] = null
		var seated := StaffManager.add_staff(member)
		if slot >= 0 and slot != seated:
			StaffManager.move_staff(seated, slot)
		_runner.note_buy("staff:", member.id, price)
		return true

	func buy_condiment(index: int) -> bool:
		var condiment := condiments[index]
		if condiment == null or not CondimentManager.can_add():
			return false
		var price := price_of(condiment)
		if not EconomyManager.can_afford(price):
			return false
		EconomyManager.remove(price)
		condiments[index] = null
		CondimentManager.add_condiment(condiment)
		_runner.note_buy("condiment:", condiment.id, price)
		return true

	func reroll() -> bool:
		if not EconomyManager.can_afford(reroll_cost):
			return false
		EconomyManager.remove(reroll_cost)
		reroll_cost += 1
		_reroll_count += 1
		_roll_stock()
		_runner.note_merchant_reroll()
		return true


var map: HexTileMap
var sim: RefCounted
## The bot's hand. Every card the game hands out arrives through tile_card_selected.
var hand: Array[TileCard] = []
var power_mode := false
var use_condiments := true
var policy: RefCounted
## Step-by-step log for hunting a stuck or runaway run.
var trace_enabled := false

var _chef_ids: Array[String] = []
var _run_count := DEFAULT_RUN_COUNT
var _only_seed := ""
var _repeat := 1
var _difficulty := 0
var _fuzz := false
var _check_sim := false
var _verbose := false
var _report_path := REPORT_PATH
var _cases: Array[Dictionary] = []
var _failed := 0

var _run_over := false
var _won := false
## Actions and day results for the run in progress. Becomes the report's details.
var _log: Dictionary = {}
var _day: Dictionary = {}
var _run_script_errors: Array[String] = []
var _pending_turn_script_errors: Array[String] = []


func _enter_tree() -> void:
	SCRIPT_ERROR_TRACKER.ensure_logger()
	GameManager.skip_presentation = true
	GameManager.playtest_real_day_flow = true


func _ready() -> void:
	_parse_args()
	GameManager.playtest_play_full_day = power_mode
	print("[playtest] chefs=%s runs=%d seed=%s difficulty=%d mode=%s condiments=%s" % [
		",".join(_chef_ids),
		_run_count,
		_only_seed if not _only_seed.is_empty() else "-",
		_difficulty,
		"fuzz" if _fuzz else ("power" if power_mode else "normal"),
		"on" if use_condiments else "off",
	])
	map = HEX_MAP_SCENE.instantiate() as HexTileMap
	add_child(map)
	sim = PLAYTEST_SIM.new(map)
	sim.check_purity = _check_sim
	if trace_enabled:
		sim.trace = trace
	EventBus.tile_card_selected.connect(_on_card_granted)
	EventBus.game_ended.connect(_on_game_ended)
	EventBus.station_choice_requested.connect(_on_station_choice_requested)
	await get_tree().process_frame
	await _run_all()
	_write_report()
	get_tree().quit(1 if _failed > 0 else 0)


func _parse_args() -> void:
	var requested_chef := ""
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1).strip_edges() if "=" in arg else ""
		if arg.begins_with("--chef="):
			requested_chef = value.to_lower()
		elif arg.begins_with("--runs="):
			_run_count = maxi(1, int(value))
		elif arg.begins_with("--seed="):
			_only_seed = value
		elif arg.begins_with("--repeat="):
			_repeat = maxi(1, int(value))
		elif arg.begins_with("--difficulty="):
			_difficulty = clampi(int(value), 0, Difficulty.Level.size() - 1)
		elif arg.begins_with("--out="):
			_report_path = value
		elif arg == "--power":
			power_mode = true
		elif arg == "--fuzz":
			_fuzz = true
		elif arg == "--no-condiments":
			use_condiments = false
		elif arg == "--no-overplay":
			TileCard.overplay_enabled = false
		elif arg == "--check-sim":
			_check_sim = true
		elif arg == "--verbose":
			_verbose = true
		elif arg == "--trace":
			trace_enabled = true
			_verbose = true
		else:
			push_error("PlaytestRunner: unknown argument %s" % arg)
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		if requested_chef.is_empty() or chef.id == requested_chef:
			_chef_ids.append(chef.id)
	if _chef_ids.is_empty():
		push_error("PlaytestRunner: unknown chef %s" % requested_chef)
		for chef: ChefDefinition in ChefRegistry.get_all_chefs():
			_chef_ids.append(chef.id)
	# Fuzz keeps playing through all nine days, so it never stops on a missed goal.
	if _fuzz:
		power_mode = true


func _run_all() -> void:
	var suite := "fuzz" if _fuzz else ("power" if power_mode else "run")
	if not _only_seed.is_empty():
		for chef_id: String in _chef_ids:
			for repeat_index in _repeat:
				await _run_one(suite, chef_id, _only_seed, repeat_index)
		_print_summary(suite)
		return
	if suite == "run":
		_run_starter_fairness()
	for index in _run_count:
		# Seeds are shared by every chef so chef results compare on the same offers.
		var seed_text := "%s%03d" % ["FZ" if _fuzz else "RUN", index]
		for chef_id: String in _chef_ids:
			await _run_one(suite, chef_id, seed_text, 0)
	_print_summary(suite)


#region Starter hand

## Opening hand is 3 Ingredients and 2 Kitchenware, all tagged starting_hand_eligible.
func _run_starter_fairness() -> void:
	for chef_id: String in _chef_ids:
		GameManager.selected_chef = ChefRegistry.get_chef_by_id(chef_id)
		GameManager.selected_difficulty = Difficulty.Level.LEVEL_0
		for index in STARTER_SEED_COUNT:
			var seed_text := "ST%s%03d" % [chef_id.substr(0, 3).to_upper(), index]
			RunRng.begin_new_run(seed_text)
			var ids: Array[String] = []
			var ingredients := 0
			var kitchenware := 0
			var reasons: Array[String] = []
			for card: TileCard in _deal_starting_hand():
				ids.append(card.id)
				if not card.starting_hand_eligible:
					reasons.append("%s is not starting_hand_eligible" % card.id)
				match card.type:
					TileCard.TileCardType.INGREDIENT:
						ingredients += 1
					TileCard.TileCardType.KITCHENWARE:
						kitchenware += 1
					_:
						reasons.append("unexpected Meal %s" % card.id)
			if ingredients != ChefRegistry.STARTING_INGREDIENT_COUNT:
				reasons.append("expected %d Ingredients, got %d" % [ChefRegistry.STARTING_INGREDIENT_COUNT, ingredients])
			if kitchenware != ChefRegistry.STARTING_KITCHENWARE_COUNT:
				reasons.append("expected %d Kitchenware, got %d" % [ChefRegistry.STARTING_KITCHENWARE_COUNT, kitchenware])
			_record("starter_fairness", chef_id, seed_text, reasons, {"hand": ids})


## Same stream as Hand.build_starting_hand, so a seed deals the hand a player would see.
func _deal_starting_hand() -> Array[TileCard]:
	var dealt: Array[TileCard] = []
	var stream_name := "starting_hand:%s:%d" % [GameManager.selected_chef.id, int(GameManager.selected_difficulty)]
	RunRng.using_fresh_stream(stream_name, func() -> void:
		dealt.append_array(ChefRegistry.get_starting_hand_cards(GameManager.selected_chef))
	)
	return dealt

#endregion

#region Run driver

func _run_one(suite: String, chef_id: String, seed_text: String, repeat_index: int) -> void:
	var started_msec := Time.get_ticks_msec()
	var sims_before: int = sim.simulations_run
	sim.resolve_msec = 0.0
	sim.evaluate_msec = 0.0
	sim.slowest_resolve_msec = 0.0
	policy = (CHAOS_POLICY if _fuzz else HUMAN_POLICY).new()
	policy.runner = self
	_begin_run(chef_id, seed_text)
	policy.on_run_started()

	var hours := 0
	var day_round := -1
	while not _run_over and hours < MAX_HOURS_PER_RUN:
		# Lets queue_free'd card UI go. A headless Hour can finish without a frame passing.
		await get_tree().process_frame
		trace("day %d step %s remaining %d score %d/%d hand %d gold %d" % [
			GameManager.current_round,
			RoundFlow.Step.find_key(RoundFlow.get_step()),
			GameManager.remaining_turns,
			GameManager.total_round_score,
			GameManager.required_score,
			hand.size(),
			EconomyManager.amount,
		])
		match RoundFlow.get_step():
			RoundFlow.Step.IDLE:
				if day_round != GameManager.current_round:
					day_round = GameManager.current_round
					await _start_day()
				await _play_hour()
				hours += 1
			RoundFlow.Step.SUMMARY:
				if trace_enabled:
					_trace_node_owners()
				_close_day()
				RoundFlow.notify_summary_confirmed()
			RoundFlow.Step.CARD_PICK:
				await _draft(true, RoundFlow.get_transition_card_pick_round(), GameManager.remaining_turns)
				RoundFlow.notify_card_picked()
			RoundFlow.Step.MERCHANT:
				await policy.shop(MerchantVisit.new(self))
				EventBus.merchant_closed.emit()
			RoundFlow.Step.EVENT_REVEAL:
				EventBus.event_reveal_finished.emit()
			RoundFlow.Step.VICTORY:
				_close_day()
				_won = true
				_run_over = true

	var reasons: Array[String] = []
	reasons.append_array(_log["invariants"])
	if not _run_over:
		reasons.append("run did not finish within %d Hours" % MAX_HOURS_PER_RUN)
	if _check_sim:
		reasons.append_array(sim.purity_failures)
		sim.purity_failures.clear()
	var details := _log.duplicate()
	details.erase("invariants")
	details["bot"] = policy.id
	details["won"] = _won
	details["reached_round"] = ScoreProgression.RUN_LENGTH_ROUNDS if _won else GameManager.current_round
	details["gold"] = EconomyManager.amount
	details["staff"] = StaffManager.owned_ids()
	details["difficulty"] = _difficulty
	details["power"] = power_mode
	details["playtest_condiments"] = use_condiments
	details["overplay"] = TileCard.overplay_enabled
	details["repeat_index"] = repeat_index
	details["sims"] = sim.simulations_run - sims_before
	details["sim_seconds"] = snappedf(sim.evaluate_msec / 1000.0, 0.1)
	details["sim_resolve_seconds"] = snappedf(sim.resolve_msec / 1000.0, 0.1)
	details["slowest_sim_ms"] = roundi(sim.slowest_resolve_msec)
	details["seconds"] = snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1)
	_record(suite, chef_id, seed_text, reasons, details)


func _begin_run(chef_id: String, seed_text: String) -> void:
	_run_script_errors.clear()
	_pending_turn_script_errors.clear()
	SCRIPT_ERROR_TRACKER.mark()
	GameManager.selected_chef = ChefRegistry.get_chef_by_id(chef_id)
	GameManager.selected_difficulty = _difficulty as Difficulty.Level
	RunRng.begin_new_run(seed_text)
	GameManager.reset_for_new_run()
	_clear_board()
	map.generate_terrain()
	map.apply_run_start_randomization()
	_run_over = false
	_won = false
	_day = {}
	_log = {
		"picks": [],
		"buys": [],
		"sells": [],
		"plays": 0,
		"merges": [],
		"replaces": [],
		"rerolls": 0,
		"merchant_rerolls": 0,
		"drinks": [],
		"perks": [],
		"staff_moves": 0,
		"days": [],
		"invariants": [],
	}
	hand.clear()
	EventBus.turn_started.emit()
	hand.append_array(_deal_starting_hand())


func _clear_board() -> void:
	for hex: Hex in map.map_data.values():
		if hex.active_tile_card != null:
			hex.remove_tile_card()
	map.reset_hour_results()


func _start_day() -> void:
	_day = {
		"round": GameManager.current_round,
		"goal": GameManager.required_score,
		"event": EventManager.get_active_event_name(),
		"hours": 0,
		"leftover_hours": 0,
	}
	if power_mode:
		# The goal above is kept for the report. Zero lets every Hour of the day play out.
		GameManager.required_score = 0
	await policy.on_day_started()


func _play_hour() -> void:
	var goal_met_before := GameManager.total_round_score >= GameManager.required_score
	if hand.is_empty():
		_note_invariant("empty hand at the start of an Hour")
	# The Hour ends once a play or sell leaves fewer than three cards in hand.
	var removed := 0
	while not hand.is_empty() and (hand.size() >= 3 or removed == 0):
		if removed >= MAX_ACTIONS_PER_HOUR:
			_note_invariant("Hour needed more than %d hand actions" % MAX_ACTIONS_PER_HOUR)
			break
		trace("choosing hand action")
		var action: Dictionary = await policy.choose_hand_action(hand)
		trace("hand action %s %s" % [action.get("card").id if action.get("card") else "?", "sell" if action.get("sell", false) else str(action.get("hex").coordinates if action.get("hex") else "")])
		_apply_hand_action(action)
		removed += 1

	trace("before resolve")
	await policy.before_resolve()
	trace("resolving Hour")
	_day["hours"] = int(_day["hours"]) + 1
	if goal_met_before:
		_day["leftover_hours"] = int(_day["leftover_hours"]) + 1
	var score_before := GameManager.total_round_score
	await _resolve_turn()
	for reason: String in _collect_invariant_failures(score_before):
		_note_invariant(reason)
	if _run_over or RoundFlow.is_transitioning():
		return

	# The day goes on. Every new Hour brings a card pick, rolled before the Hour was used up.
	if EventManager.should_auto_grant_card(false):
		EventManager.grant_auto_card(false, GameManager.remaining_turns + 1)
	elif EventManager.get_cards_pack_size(false) > 0:
		await _draft(false, GameManager.current_round, GameManager.remaining_turns + 1)


func _apply_hand_action(action: Dictionary) -> void:
	var card: TileCard = action.get("card")
	if card == null or not hand.has(card):
		_note_invariant("bot chose a card that is not in hand")
		card = hand[0]
		action = {"card": card, "sell": true}
	var hex: Hex = action.get("hex")
	if not bool(action.get("sell", false)) and (hex == null or not card.can_play_on(hex)):
		_note_invariant("bot chose an illegal spot for %s" % card.id)
		var legal := legal_hexes(card)
		hex = legal[0] if not legal.is_empty() else null
	hand.erase(card)
	if bool(action.get("sell", false)) or hex == null:
		EconomyManager.add(CardSellPanel.SELL_VALUE)
		_log["sells"].append("%d:%s" % [GameManager.current_round, card.id])
		return
	match card.get_overplay(hex):
		TileCard.Overplay.MERGE:
			_log["merges"].append("%d:%s>%d" % [GameManager.current_round, card.id, hex.active_tile_card.star_level + 1])
		TileCard.Overplay.REPLACE:
			_log["replaces"].append("%d:%s>%s" % [GameManager.current_round, hex.active_tile_card.id, card.id])
	card.play_on(hex)
	StationManager.evaluate_station_types()
	_log["plays"] = int(_log["plays"]) + 1


func _draft(is_reward: bool, round_number: int, first_remaining_turns: int) -> void:
	var reroll_index := 0
	while true:
		# The panel rolls its first offer before the Hour is used up and each reroll after.
		var remaining := first_remaining_turns if reroll_index == 0 else GameManager.remaining_turns
		var offer := CardSelectionUI.draw_offer(round_number, remaining, is_reward, reroll_index)
		if offer.is_empty():
			return
		var choice: int = await policy.choose_offer(offer, is_reward)
		if choice < 0 and EconomyManager.use_reroll():
			reroll_index += 1
			_log["rerolls"] = int(_log["rerolls"]) + 1
			continue
		var card := offer[clampi(choice, 0, offer.size() - 1)]
		_log["picks"].append("%s%d:%s" % ["reward" if is_reward else "", round_number, card.id])
		EventBus.tile_card_selected.emit(card)
		return


func _resolve_turn() -> void:
	EventBus.turn_ended.emit()
	while GameManager.is_processing_turn:
		await get_tree().process_frame
	_pending_turn_script_errors = SCRIPT_ERROR_TRACKER.collect_new()
	for script_err: String in _pending_turn_script_errors:
		_run_script_errors.append(script_err)
		print("[playtest]   SCRIPT %s" % script_err)


func _close_day() -> void:
	if _day.is_empty():
		return
	var score := GameManager.total_round_score
	_day["score"] = score
	_day["cleared"] = score >= int(_day["goal"])
	_day["gold"] = EconomyManager.amount
	var stations: Array = []
	for segment_index in map.get_segment_count():
		var station_type := StationManager.get_station_type(segment_index)
		stations.append({
			"type": station_type.id if station_type != null else "",
			"level": StationManager.get_level(segment_index),
		})
	_day["stations"] = stations
	_log["days"].append(_day)
	if _verbose:
		print("[playtest]   day %d %d/%d hours=%d leftover=%d gold=%d" % [
			int(_day["round"]),
			score,
			int(_day["goal"]),
			int(_day["hours"]),
			int(_day["leftover_hours"]),
			EconomyManager.amount,
		])
	_day = {}


func _on_card_granted(card: TileCard) -> void:
	if sim.is_simulating or card == null:
		return
	hand.append(card)


func _on_game_ended() -> void:
	if sim.is_simulating:
		return
	_close_day()
	_run_over = true


func _on_station_choice_requested(segment_index: int) -> void:
	var choice: int = policy.choose_station_perk(segment_index) if policy != null else 0
	StationManager.resolve_choice(segment_index, choice)
	if not sim.is_simulating:
		_log["perks"].append("%d:%d:%d" % [GameManager.current_round, segment_index, choice])

#endregion

## Largest groups of nodes by parent and class, to find nodes that pile up over a run.
func _trace_node_owners() -> void:
	var counts: Dictionary = {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
			var key := "%s > %s" % [node.name, child.get_class()]
			counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	for key: String in keys.slice(0, 8):
		print("[trace]   nodes %s x%d" % [key, counts[key]])

#region Helpers for policies

func trace(message: String) -> void:
	if trace_enabled:
		print("[trace] %s mem=%dMB objects=%d resources=%d nodes=%d orphans=%d" % [
			message,
			OS.get_static_memory_usage() / 1048576,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		])


func legal_hexes(card: TileCard) -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in map.get_hexes_in_trigger_order():
		if card.can_play_on(hex):
			hexes.append(hex)
	return hexes


## True while a regular spot is open.
func board_has_room() -> bool:
	for hex: Hex in map.get_hexes_in_trigger_order():
		if hex.active_tile_card == null and not hex.is_placement_blocked() and not map.is_meal_slot(hex.coordinates):
			return true
	return false


func drink_condiment(slot: int, hex: Hex = null, hex_b: Hex = null) -> bool:
	var condiment: Condiment = CondimentManager.belt[slot]
	if condiment == null or not CondimentManager.headless_use_slot(slot, hex, hex_b):
		return false
	_log["drinks"].append("%d:%s" % [GameManager.current_round, condiment.id])
	return true


func move_staff(from_slot: int, to_slot: int) -> bool:
	if not StaffManager.move_staff(from_slot, to_slot):
		return false
	_log["staff_moves"] = int(_log["staff_moves"]) + 1
	return true


func sell_staff(slot: int) -> bool:
	var staff := StaffManager.get_staff(slot)
	if staff == null or StaffManager.sell_staff(slot) < 0:
		return false
	_log["sells"].append("%d:staff:%s" % [GameManager.current_round, staff.id])
	return true


func note_buy(kind: String, item_id: String, price: int) -> void:
	_log["buys"].append("%d:%s%s@%d" % [GameManager.current_round, kind, item_id, price])


func note_merchant_reroll() -> void:
	_log["merchant_rerolls"] = int(_log["merchant_rerolls"]) + 1

#endregion

#region Invariants

func _note_invariant(reason: String) -> void:
	_log["invariants"].append("day %d: %s" % [GameManager.current_round, reason])
	print("[playtest]   INVARIANT day %d %s" % [GameManager.current_round, reason])


func _collect_invariant_failures(score_before: int) -> Array[String]:
	var reasons: Array[String] = []
	var storm := map.turn_resolver != null and map.turn_resolver.aborted_retrigger_storm
	if storm:
		reasons.append("retrigger storm aborted at %d activations" % HexTurnResolver.SKIP_PRESENTATION_STORM_LIMIT)
	if EconomyManager.amount < 0:
		reasons.append("gold went negative (%d)" % EconomyManager.amount)
	if GameManager.remaining_turns < 0:
		reasons.append("remaining_turns went negative (%d)" % GameManager.remaining_turns)

	var seen_instances: Dictionary = {}
	var occupied_by_segment: Dictionary = {}
	for hex: Hex in map.get_hexes_in_trigger_order():
		var card := hex.active_tile_card
		if card == null:
			continue
		if card.id.strip_edges().is_empty():
			reasons.append("placed card with empty id at %s" % str(hex.coordinates))
		var instance_id := card.get_instance_id()
		if seen_instances.has(instance_id):
			reasons.append("same card instance on %s and %s" % [str(seen_instances[instance_id]), str(hex.coordinates)])
		else:
			seen_instances[instance_id] = hex.coordinates
		if map.get_hex_for_tile_card(card) != hex:
			reasons.append("get_hex_for_tile_card mismatch for %s" % card.id)
		var segment_index := map.get_segment_index(hex.coordinates)
		if segment_index < 0 or segment_index >= map.get_segment_count():
			reasons.append("hex %s has segment_index %d" % [str(hex.coordinates), segment_index])
		occupied_by_segment[segment_index] = int(occupied_by_segment.get(segment_index, 0)) + 1

	for index in map.get_segment_count():
		if int(occupied_by_segment.get(index, 0)) > map.get_segment_size(index):
			reasons.append("segment %d has more cards than tiles" % index)
		var flavour := map.get_segment_turn_flavour(index)
		var additive := map.get_segment_additive_mult(index)
		var multiplicative := map.get_segment_multiplicative_mult(index)
		if flavour < 0:
			reasons.append("segment %d flavour %d" % [index, flavour])
		if is_nan(additive) or is_inf(additive) or additive < 0.0:
			reasons.append("segment %d additive mult %s" % [index, str(additive)])
		if is_nan(multiplicative) or is_inf(multiplicative) or multiplicative < 0.0:
			reasons.append("segment %d multiplicative mult %s" % [index, str(multiplicative)])

	var expected := GameManager.compute_hour_turn_contribution(map.get_hour_flavour(), map.get_hour_additive_mult())
	var delta := GameManager.total_round_score - score_before
	# A day that just ended has already moved on, so only check Hours inside the day.
	if not storm and not RoundFlow.is_transitioning() and not _run_over and delta != expected:
		reasons.append("Hour score delta %d != Hour rating %d" % [delta, expected])
	for script_err: String in _pending_turn_script_errors:
		reasons.append("script error: %s" % script_err)
	return reasons

#endregion

#region Report

func _record(suite: String, chef_id: String, seed_text: String, reasons: Array[String], details: Dictionary) -> void:
	for script_err: String in SCRIPT_ERROR_TRACKER.collect_new():
		_run_script_errors.append(script_err)
	for script_err: String in _run_script_errors:
		reasons.append("script error: %s" % script_err)
	var passed := reasons.is_empty()
	if not passed:
		_failed += 1
	_cases.append({
		"suite": suite,
		"chef": chef_id,
		"seed": seed_text,
		"passed": passed,
		"reasons": reasons,
		"details": details,
	})
	if suite == "starter_fairness":
		if not passed:
			print("[playtest] FAIL starter_fairness %s %s — %s" % [chef_id, seed_text, ", ".join(reasons)])
		return
	var outcome := "won" if bool(details.get("won", false)) else "lost day %d" % int(details.get("reached_round", 0))
	if suite != "run":
		outcome = "reached day %d" % int(details.get("reached_round", 0))
	print("[playtest] %s %s/%s %s %s: %s gold=%d %.1fs%s" % [
		"PASS" if passed else "FAIL",
		suite,
		details.get("bot", "-"),
		chef_id,
		seed_text,
		outcome,
		int(details.get("gold", 0)),
		float(details.get("seconds", 0.0)),
		"" if passed else " — %s" % ", ".join(reasons),
	])


func _print_summary(suite: String) -> void:
	print("[playtest] --- %s summary by chef ---" % suite)
	for chef_id: String in _chef_ids:
		var runs := 0
		var wins := 0
		var reached_sum := 0
		var gold_sum := 0
		var loss_days: Dictionary = {}
		var day_ratio_sum: Dictionary = {}
		var day_ratio_count: Dictionary = {}
		var leftover_hours := 0
		var day_count := 0
		var seconds := 0.0
		for case_data: Dictionary in _cases:
			if case_data["suite"] != suite or case_data["chef"] != chef_id:
				continue
			var details: Dictionary = case_data["details"]
			runs += 1
			seconds += float(details.get("seconds", 0.0))
			gold_sum += int(details.get("gold", 0))
			var reached := int(details.get("reached_round", 0))
			reached_sum += reached
			if bool(details.get("won", false)):
				wins += 1
			else:
				loss_days[reached] = int(loss_days.get(reached, 0)) + 1
			for day: Dictionary in details.get("days", []):
				var round_number := int(day["round"])
				var goal := maxi(1, int(day["goal"]))
				day_ratio_sum[round_number] = float(day_ratio_sum.get(round_number, 0.0)) + float(day["score"]) / float(goal)
				day_ratio_count[round_number] = int(day_ratio_count.get(round_number, 0)) + 1
				leftover_hours += int(day["leftover_hours"])
				day_count += 1
		if runs <= 0:
			continue
		var ratios: PackedStringArray = []
		for round_number in range(1, ScoreProgression.RUN_LENGTH_ROUNDS + 1):
			if day_ratio_count.has(round_number):
				ratios.append("%.2f" % (float(day_ratio_sum[round_number]) / float(day_ratio_count[round_number])))
			else:
				ratios.append("-")
		# Power and fuzz days have no goal, so a finished run is not a win.
		print("[playtest]   %s  %d/%d %s (%.0f%%)  avg day %.1f  losses %s  gold %.1f  %.0fs/run" % [
			chef_id,
			wins,
			runs,
			"wins" if suite == "run" else "completed",
			100.0 * float(wins) / float(runs),
			float(reached_sum) / float(runs),
			str(loss_days),
			float(gold_sum) / float(runs),
			seconds / float(runs),
		])
		print("[playtest]     score/goal by day [%s]  leftover Hours/day %.2f" % [
			" ".join(ratios),
			float(leftover_hours) / float(maxi(1, day_count)),
		])


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
	print("[playtest] wrote %s (%d failed / %d total)" % [ProjectSettings.globalize_path(_report_path), _failed, _cases.size()])

#endregion
