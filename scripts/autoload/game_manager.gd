extends Node

## Central coordinator for run flow: turns, scoring, rounds, resource pools, and turn processing.

signal game_speed_changed(new_speed: float)

## Number of runes in a rune pack, picked at the end of each turn
const CARDS_PACK_SIZE := 3
const MAX_TURNS_PER_ROUND := 4

var current_round: int = 1
## Highest completed/current round score reached during this run.
var highest_round_score: int = 0

## Total tile card activations this run, shown on the game-over screen.
## Stored on RunLedger so payoff tallies and history share one run fire count.
var total_rune_activations: int:
	get:
		return RunLedger.total_fires

#region Turn state
## Remaining turns in the current round (counts down from get_max_turns_per_round()).
var _remaining_turns := MAX_TURNS_PER_ROUND
## Blocks player input while runes are resolving after end turn.
var _is_processing_turn := false

var remaining_turns: int:
	get:
		return _remaining_turns
	set(value):
		_remaining_turns = value

var is_processing_turn: bool:
	get:
		return _is_processing_turn

#endregion

#region Score and round progression

## Score needed to complete the current round and open the merchant.
var required_score: int = ScoreProgression.get_required_score(1)

## total score earned in the current round. 
var _total_round_score: int = 0
## Score earned during the current turn
var _turn_score: int = 0

var total_round_score: int:
	get:
		return _total_round_score
	set(value):
		_total_round_score = value
		highest_round_score = maxi(highest_round_score, _total_round_score)
		EventBus.total_round_score_changed.emit()

var turn_score: int:
	get:
		return _turn_score
	set(value):
		_turn_score = value

#endregion

#region Tile card pool

## Every rune resource loaded from disk at startup.
var tile_cards_pool: Array[TileCard] = []
## Same pool keyed by card id. Startup load and get_tile_card_by_id share this index.
var _tile_cards_by_id: Dictionary = {}

#endregion

#region TileCard activation tracking

## This-Hour fire counts keyed by card instance. Used for resolve identity, not payoff tallies.
var _activation_counts_this_turn: Dictionary = {}
## Incremented on each turn_started, placed runes use this to gate once-per-turn permanent effects.
var turn_stamp: int = 0

#endregion

#region Chef selection

## Chosen on the chef selection screen. Drives chef speciality and starting hand.
var selected_chef: ChefDefinition = null
var selected_difficulty: Difficulty.Level = Difficulty.Level.LEVEL_0
const ChefSpecialityRuntimeScript := preload("res://scripts/chef_speciality_runtime.gd")
var chef_speciality := ChefSpecialityRuntimeScript.new()

#endregion

#region Run peak tracking

var _run_peak_triggers_single_turn: int = 0
var _run_peak_segment_score_single_turn: int = 0
var _run_peak_gold_held: int = 0
var _current_turn_trigger_count: int = 0

#endregion

## Headless playtests skip UI awaits, rune-pick panels, and round-flow screens.
var skip_presentation: bool = false

#region Game speed

var _game_speed: float = 1.0

var game_speed: float:
	get:
		return _game_speed
	set(value):
		_game_speed = GameSettings.normalize_game_speed(value)
		game_speed_changed.emit(_game_speed)

#endregion

func _ready() -> void:
	GameSettings.ensure_loaded()
	game_speed = GameSettings.game_speed
	if selected_chef == null:
		selected_chef = ChefRegistry.get_default_chef()

	_load_tile_cards_from_directory("res://resources/spot_cards/")

	if tile_cards_pool.is_empty():
		push_error("No tile cards loaded into pool from res://resources/spot_cards/")

	_sort_tile_cards_pool()

	EventBus.turn_ended.connect(end_turn)
	EventBus.turn_started.connect(_on_turn_started)
#region Turn flow

## Pause after the top-panel round score lands before rune pick or round summary.
const POST_ROUND_SCORE_PANEL_DELAY := 0.75

func end_turn() -> void:
	_is_processing_turn = true


func finish_turn_processing() -> void:
	CondimentManager.on_turn_resolved()

	var committed_turn_score := turn_score
	var round_score_before := total_round_score
	total_round_score += turn_score
	turn_score = 0
	if not skip_presentation:
		EventBus.round_score_commit_animation_requested.emit(committed_turn_score, round_score_before)
		await _wait_for_round_score_count_finished()
		await GameManager.create_pauseable_timer(POST_ROUND_SCORE_PANEL_DELAY / game_speed).timeout

	var goal_met := _has_met_round_goal()
	# Leftover hours stay playable after the goal. The End Day button closes the day early.
	# Headless playtests own their round loop, so they still stop at the goal.
	var keep_playing := goal_met and remaining_turns > 1 and not skip_presentation
	var should_consume_turn := remaining_turns > 0 and (not goal_met or keep_playing)

	if goal_met and not keep_playing:
		if skip_presentation:
			pass
		else:
			_complete_current_round()
	else:
		# Every new hour gets a card pick, including leftover hours after the goal.
		if not skip_presentation:
			if EventManager.should_auto_grant_card(false):
				EventManager.grant_auto_card(false, remaining_turns)
			elif EventManager.get_cards_pack_size(false) > 0:
				UiManager.show_cards_choice_panel.emit()
		EventBus.turn_started.emit()

	if should_consume_turn:
		remaining_turns -= 1
		EventBus.turn_changed.emit()
		if not _has_met_round_goal():
			_check_run_loss()

	_is_processing_turn = false
	# Committed turn boundary. Card plays themselves are not checkpoints.
	RunSaveManager.request_autosave()


func _wait_for_round_score_count_finished() -> void:
	await EventBus.round_score_count_finished


func _on_turn_started() -> void:
	turn_stamp += 1
	_activation_counts_this_turn.clear()
	_current_turn_trigger_count = 0
	GoldManager.reset_turn_tracking()
	chef_speciality.reset_turn()


func _has_met_round_goal() -> bool:
	return total_round_score >= required_score


## The run ends when a failed turn uses up the last remaining turn.
func _check_run_loss() -> void:
	if _remaining_turns > 0:
		return
	EventBus.game_ended.emit()


func get_max_turns_per_round() -> int:
	return EventManager.get_max_turns_per_round()


## Ascending turn index within the round (1 on the first turn, max on the last).
## Use when effects scale with how far into the round you are, not remaining turns.
func get_turn_number() -> int:
	return get_max_turns_per_round() - remaining_turns + 1


## Completed Hours in this run. turn_stamp includes the Hour currently in progress.
func get_passed_hour_count() -> int:
	return maxi(turn_stamp - 1, 0)


## Turns not used before the round goal was met. Rewards use this, not raw remaining_turns.
func get_skipped_turns() -> int:
	return maxi(0, remaining_turns - 1)


## Borrowed Time and similar drinks add a turn without changing the event.
func add_bonus_turn() -> void:
	remaining_turns += 1
	EventBus.turn_changed.emit()


## True between hours once the day target is met, while the End Day button may be used.
func can_end_day_early() -> bool:
	if _is_processing_turn or RoundFlow.is_transitioning():
		return false
	return _has_met_round_goal() and remaining_turns > 0


## End Day button. Closes the day at the start of an hour instead of playing it.
func end_day_early() -> void:
	if not can_end_day_early():
		return
	# The hour in progress was not played, so every remaining hour counts as unused.
	_complete_current_round(remaining_turns)


## Debug helper. Sets the round score to the goal and starts the normal complete-round flow.
## Skips tile resolution so a sandbox can jump straight to the summary, rune pick, and merchant.
func debug_meet_round_goal_and_complete() -> void:
	if _is_processing_turn or RoundFlow.is_transitioning():
		return
	_turn_score = 0
	total_round_score = required_score
	_complete_current_round()


## Hands the completed round to RoundFlow, which owns every step up to the next turn.
## The summary screen reads remaining turns and gold earned, so nothing advances until Continue.
func _complete_current_round(skipped_turns: int = get_skipped_turns()) -> void:
	GoldManager.apply_round_speed_rewards(skipped_turns)
	StaffManager.on_day_ended()
	if EventManager.is_completing_final_event_round():
		RoundFlow.begin_victory_transition()
		return

	RoundFlow.begin_round_transition()


func advance_round() -> void:
	current_round += 1
	# Round-spend counters reset before the round bonus so cards start fresh.
	GoldManager.reset_round_tracking()
	RerollManager.reset_for_new_round()
	total_round_score = 0
	_apply_round_state()


## Round-dependent state and HUD refresh, shared by the round advance and the debug start.
func _apply_round_state() -> void:
	required_score = ScoreProgression.get_required_score(current_round)
	# Apply the event first so Rush Hour's reduced max is reflected in remaining turns.
	EventManager.on_round_advanced(current_round)
	required_score = EventManager.apply_score_modifier(required_score)
	remaining_turns = get_max_turns_per_round()
	EventBus.turn_changed.emit()
	EventBus.round_changed.emit(current_round)
	EventBus.required_score_changed.emit()

#endregion

#region TileCard activation
## Register a tile card activation from tile_card.gd activate_tile_card()
## for it to be read by hex_tile_map.gd can_consume_next_tile_card_in_trigger_order()
func register_tile_card_activation(rune: TileCard) -> void:
	var hour_count := int(_activation_counts_this_turn.get(rune, 0)) + 1
	_activation_counts_this_turn[rune] = hour_count
	var is_retrigger := hour_count >= 2
	_current_turn_trigger_count += 1
	_run_peak_triggers_single_turn = maxi(_run_peak_triggers_single_turn, _current_turn_trigger_count)
	MetaProgressionManager.add_lifetime_triggers(1)
	# Ledger owns run fire tallies. Pass retrigger so it does not scan Hour identity again.
	RunLedger.record_card_fired(rune, is_retrigger)

## Read rune activation to check if it has already fired this turn.
## Used by hex_tile_map.gd can_consume_next_tile_card_in_trigger_order()
func has_tile_card_activated_this_turn(rune: TileCard) -> bool:
	return int(_activation_counts_this_turn.get(rune, 0)) > 0


## How many times this tile card has activated so far this turn (includes the current one).
func get_tile_card_activation_count_this_turn(rune: TileCard) -> int:
	return int(_activation_counts_this_turn.get(rune, 0))

#endregion

#region Chef speciality and turn scoring

func get_current_turn_trigger_count() -> int:
	return _current_turn_trigger_count


func bind_chef_speciality() -> void:
	chef_speciality.bind(selected_chef)


## Rating is Flavour x Additive. xMult already folded into Additive when it fired.
func get_segment_turn_contribution_breakdown(
	_segment_index: int,
	flavour: int,
	additive_mult: float,
	_multiplicative_mult: float = 1.0
) -> Dictionary:
	return get_hour_turn_contribution_breakdown(flavour, additive_mult)


func get_hour_turn_contribution_breakdown(flavour: int, additive_mult: float) -> Dictionary:
	var contribution := int(round(float(flavour) * additive_mult))
	return {
		"display_flavour": flavour,
		"display_additive_mult": additive_mult,
		"display_multiplicative_mult": 1.0,
		"contribution": contribution,
	}


func compute_hour_turn_contribution(flavour: int, additive_mult: float) -> int:
	return int(get_hour_turn_contribution_breakdown(flavour, additive_mult)["contribution"])


func compute_segment_turn_contribution(
	segment_index: int,
	flavour: int,
	additive_mult: float,
	multiplicative_mult: float = 1.0
) -> int:
	return int(
		get_segment_turn_contribution_breakdown(
			segment_index,
			flavour,
			additive_mult,
			multiplicative_mult
		)["contribution"]
	)


func record_turn_segment_peaks(segment_contributions: Array[int]) -> void:
	for contribution in segment_contributions:
		_run_peak_segment_score_single_turn = maxi(_run_peak_segment_score_single_turn, contribution)
	_run_peak_triggers_single_turn = maxi(_run_peak_triggers_single_turn, _current_turn_trigger_count)


func record_peak_gold_held(amount: int) -> void:
	_run_peak_gold_held = maxi(_run_peak_gold_held, amount)


func build_run_snapshot(is_win: bool) -> Dictionary:
	var chef_id := selected_chef.id if selected_chef != null else ""
	return {
		"is_win": is_win,
		"chef_id": chef_id,
		"difficulty": int(selected_difficulty),
		"rounds_completed": current_round if is_win else maxi(0, current_round - 1),
		"peak_gold_held": _run_peak_gold_held,
		"gold_earned": GoldManager.total_earned_this_run,
		"peak_segment_score_single_turn": _run_peak_segment_score_single_turn,
		"peak_triggers_single_turn": _run_peak_triggers_single_turn,
	}


func clear_run_peak_tracking() -> void:
	_run_peak_triggers_single_turn = 0
	_run_peak_segment_score_single_turn = 0
	_run_peak_gold_held = 0
	_current_turn_trigger_count = 0

#endregion

func set_game_speed(speed: float) -> void:
	game_speed = speed
	GameSettings.set_game_speed(game_speed)


## Scene timer that stops while the pause menu freezes the tree.
## SceneTree.create_timer ignores pause unless process_always is false.
func create_pauseable_timer(duration: float) -> SceneTreeTimer:
	return get_tree().create_timer(duration, false)

#region tile card pool loading

## Recursively load every .tres TileCard under resources/spot_cards, skipping duplicate ids.
## ResourceLoader.list_directory works in exported builds. DirAccess only sees .gd files in PCK.
func _load_tile_cards_from_directory(dir_path: String) -> void:
	var normalized_path := dir_path
	if not normalized_path.ends_with("/"):
		normalized_path += "/"

	for entry in ResourceLoader.list_directory(normalized_path):
		if entry == "./" or entry == "../":
			continue

		if entry.ends_with("/"):
			# Visit subfolders first so organized copies win over legacy root duplicates.
			_load_tile_cards_from_directory(normalized_path.path_join(entry.trim_suffix("/")))
			continue

		if not entry.ends_with(".tres"):
			continue

		var resource_path := normalized_path.path_join(entry)
		var rune := ResourceLoader.load(resource_path) as TileCard
		if rune == null:
			push_error("Failed to load rune: " + resource_path)
			continue

		if _tile_cards_by_id.has(rune.id):
			continue

		tile_cards_pool.append(rune)
		_tile_cards_by_id[rune.id] = rune


func _sort_tile_cards_pool() -> void:
	tile_cards_pool.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return a.id < b.id
	)


#endregion

#region Run save / load

func reset_for_new_run() -> void:
	RoundFlow.reset_for_new_run()
	current_round = 1
	highest_round_score = 0
	_remaining_turns = MAX_TURNS_PER_ROUND
	_is_processing_turn = false
	required_score = ScoreProgression.get_required_score(current_round)
	_total_round_score = 0
	_turn_score = 0
	_activation_counts_this_turn.clear()
	turn_stamp = 0
	game_speed = GameSettings.game_speed
	clear_run_peak_tracking()
	if selected_chef != null:
		bind_chef_speciality()
	CondimentManager.reset_for_new_run()
	StaffManager.reset_for_new_run()
	RunLedger.reset_for_new_run()


## Moves a fresh run to a chosen round while keeping round-dependent state in sync.
func set_starting_round_for_debug(starting_round: int) -> void:
	_debug_apply_round_jump(maxi(1, starting_round))


## Debug helper. Teleports the live run to a round without playing the skipped rounds.
func debug_jump_to_round(target_round: int) -> void:
	if _is_processing_turn or RoundFlow.is_transitioning():
		return
	_debug_apply_round_jump(maxi(1, target_round))


## Shared round teleport used by run-start debug and the live sandbox jump field.
func _debug_apply_round_jump(target_round: int) -> void:
	RoundFlow.debug_abort_transition()
	_is_processing_turn = false
	_turn_score = 0
	total_round_score = 0
	GoldManager.reset_round_tracking()
	current_round = target_round
	_apply_round_state()
	EventBus.turn_started.emit()
	# No merchant visit precedes a debug jump, so the reveal plays right away.
	EventManager.play_reveal()
	RunSaveManager.request_autosave()


func capture_run_state() -> Dictionary:
	return {
		"highest_round_score": highest_round_score,
		"current_round": current_round,
		"remaining_turns": _remaining_turns,
		# Always idle in a checkpoint. Restoring mid-resolve would freeze input.
		"is_processing_turn": false,
		"required_score": required_score,
		"total_round_score": _total_round_score,
		"turn_score": _turn_score,
		"turn_stamp": turn_stamp,
		"game_speed": _game_speed,
		"peak_gold_held": _run_peak_gold_held,
		"peak_segment_score_single_turn": _run_peak_segment_score_single_turn,
		"peak_triggers_single_turn": _run_peak_triggers_single_turn,
	}


func apply_run_state(state: Dictionary) -> void:
	current_round = int(state.get("current_round", 1))
	highest_round_score = int(state.get("highest_round_score", state.get("total_round_score", 0)))
	_remaining_turns = int(state.get("remaining_turns", MAX_TURNS_PER_ROUND))
	_is_processing_turn = false
	required_score = int(state.get("required_score", ScoreProgression.get_required_score(current_round)))
	_total_round_score = int(state.get("total_round_score", 0))
	_turn_score = int(state.get("turn_score", 0))
	turn_stamp = int(state.get("turn_stamp", 0))
	_activation_counts_this_turn.clear()
	game_speed = float(state.get("game_speed", 1.0))
	_run_peak_gold_held = int(state.get("peak_gold_held", 0))
	_run_peak_segment_score_single_turn = int(state.get("peak_segment_score_single_turn", 0))
	_run_peak_triggers_single_turn = int(state.get("peak_triggers_single_turn", 0))
	# Continue does not go through reset_for_new_run, so re-bind chef speciality.
	if selected_chef != null:
		bind_chef_speciality()


func get_tile_card_by_id(card_id: String) -> TileCard:
	return _tile_cards_by_id.get(card_id) as TileCard


#endregion
