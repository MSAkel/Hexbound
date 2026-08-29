extends Node

## Central coordinator for run flow: turns, scoring, rounds, resource pools, and turn processing.

signal game_speed_changed(new_speed: float)

## Number of runes in a rune pack, picked at the end of each turn
const RUNES_PACK_SIZE := 3
const MAX_TURNS_PER_ROUND := 5

var current_round: int = 1
## Highest completed/current round score reached during this run.
var highest_round_score: int = 0
## Total tile card activations this run, shown on the game-over screen.
var _total_rune_activations: int = 0

var total_rune_activations: int:
	get:
		return _total_rune_activations

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

#endregion

#region TileCard activation tracking

## Cleared at turn start, filled as each rune resolves during turn processing.
var _activated_tile_cards_this_turn: Array[TileCard] = []
## Incremented on each turn_started, placed runes use this to gate once-per-turn permanent effects.
var turn_stamp: int = 0

#endregion

#region Character selection

## Chosen on the character selection screen, drives layout rules and starting hand.
var selected_character: CharacterDefinition = null
var selected_difficulty: Difficulty.Level = Difficulty.Level.LEVEL_0
## Character being edited on the segment passives screen.
var segment_passives_editor_character: CharacterDefinition = null

#endregion

#region Segment passives (active run loadout)

## segment_index -> placed passives for the current run.
var _active_passives_by_segment: Dictionary = {}
var passive_runtime := SegmentPassiveRuntime.new()
var _run_peak_triggers_single_turn: int = 0
var _run_peak_segment_score_single_turn: int = 0
var _run_peak_gold_held: int = 0
var _current_turn_trigger_count: int = 0
var _run_full_map_cards_achieved: bool = false

#endregion

## Headless playtests skip UI awaits, rune-pick panels, and round-flow screens.
var skip_presentation: bool = false

#region Game speed

var _game_speed: float = 1.0

var game_speed: float:
	get:
		return _game_speed
	set(value):
		_game_speed = clampf(value, 1.0, 3.0)
		game_speed_changed.emit(_game_speed)

#endregion

func _ready() -> void:
	GameSettings.ensure_loaded()
	game_speed = GameSettings.game_speed
	if selected_character == null:
		selected_character = PlayerCharacter.get_default_character()

	_load_tile_cards_from_directory("res://resources/tile_cards/")

	if tile_cards_pool.is_empty():
		push_error("No tile cards loaded into pool")

	_sort_tile_cards_pool()

	EventBus.turn_ended.connect(end_turn)
	EventBus.turn_started.connect(_on_turn_started)
#region Turn flow

## Pause after the top-panel round score lands before rune pick or round summary.
const POST_ROUND_SCORE_PANEL_DELAY := 0.75

func end_turn() -> void:
	_is_processing_turn = true


func finish_turn_processing() -> void:
	# A turn is only consumed when it failed to reach the round goal.
	var should_consume_turn := remaining_turns > 0 and total_round_score + turn_score < required_score

	total_round_score += turn_score
	turn_score = 0
	if not skip_presentation:
		EventBus.round_score_commit_animation_requested.emit()
		await _wait_for_round_score_count_finished()
		await GameManager.create_pauseable_timer(POST_ROUND_SCORE_PANEL_DELAY / game_speed).timeout

	if _has_met_round_goal():
		if skip_presentation:
			# RoundFlow waits on summary UI. Playtests record the clear and stop here.
			pass
		else:
			_complete_current_round()
	else:
		if not skip_presentation:
			UiManager.show_runes_choice_panel.emit()
		EventBus.turn_started.emit()

	if should_consume_turn:
		remaining_turns -= 1
		EventBus.turn_changed.emit()
		_check_run_loss()

	_is_processing_turn = false
	RunSaveManager.request_autosave()


func _wait_for_round_score_count_finished() -> void:
	await EventBus.round_score_count_finished


func _on_turn_started() -> void:
	turn_stamp += 1
	_activated_tile_cards_this_turn.clear()
	_current_turn_trigger_count = 0
	GoldManager.reset_turn_tracking()
	passive_runtime.reset_turn()


func _has_met_round_goal() -> bool:
	return total_round_score >= required_score


## The run ends when a failed turn uses up the last remaining turn.
func _check_run_loss() -> void:
	if _remaining_turns > 0:
		return
	EventBus.game_ended.emit()


func get_max_turns_per_round() -> int:
	return ChallengeManager.get_max_turns_per_round()


## Ascending turn index within the round (1 on the first turn, max on the last).
## Use when effects scale with how far into the round you are, not remaining turns.
func get_turn_number() -> int:
	return get_max_turns_per_round() - remaining_turns + 1


## Turns not used before the round goal was met. Rewards use this, not raw remaining_turns.
func get_skipped_turns() -> int:
	return maxi(0, remaining_turns - 1)


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
func _complete_current_round() -> void:
	GoldManager.apply_round_speed_rewards(get_skipped_turns())
	if ChallengeManager.is_completing_final_challenge_round():
		RoundFlow.begin_victory_transition()
		return

	RoundFlow.begin_round_transition()


func advance_round() -> void:
	current_round += 1
	# Round-spend counters reset before the round bonus so cards start fresh.
	GoldManager.reset_round_tracking()
	total_round_score = 0
	_apply_round_state()


## Round-dependent state and HUD refresh, shared by the round advance and the debug start.
func _apply_round_state() -> void:
	required_score = ScoreProgression.get_required_score(current_round)
	# Apply the challenge first so Rush Hour's reduced max is reflected in remaining turns.
	ChallengeManager.on_round_advanced(current_round)
	remaining_turns = get_max_turns_per_round()
	EventBus.turn_changed.emit()
	EventBus.round_changed.emit(current_round)
	EventBus.required_score_changed.emit()

#endregion

#region TileCard activation
## Register a tile card activation from tile_card.gd activate_tile_card() 
## for it to be read by hex_tile_map.gd can_consume_next_tile_card_in_trigger_order()
func register_tile_card_activation(rune: TileCard) -> void:
	_activated_tile_cards_this_turn.append(rune)
	_total_rune_activations += 1
	_current_turn_trigger_count += 1
	_run_peak_triggers_single_turn = maxi(_run_peak_triggers_single_turn, _current_turn_trigger_count)
	if not RunRng.is_unlock_progress_disabled():
		MetaProgressionManager.add_lifetime_triggers(1)
		if rune.type == TileCard.TileCardType.PRODUCER:
			MetaProgressionManager.add_producer_trigger()
			if rune.product == TileCard.Product.SCORE:
				MetaProgressionManager.note_energy_card_triggers(rune.run_trigger_count)
			elif rune.product == TileCard.Product.MULTIPLIER:
				MetaProgressionManager.note_mult_card_triggers(rune.run_trigger_count)
		elif rune.type == TileCard.TileCardType.SUPPORT:
			MetaProgressionManager.add_support_trigger()
		if _activated_tile_cards_this_turn.count(rune) >= 2:
			if rune.type == TileCard.TileCardType.PRODUCER:
				MetaProgressionManager.add_producer_retrigger()
			elif rune.type == TileCard.TileCardType.SUPPORT:
				MetaProgressionManager.add_support_retrigger()

## Read rune activation to check if it has already fired this turn.
## Used by hex_tile_map.gd can_consume_next_tile_card_in_trigger_order()
func has_tile_card_activated_this_turn(rune: TileCard) -> bool:
	return _activated_tile_cards_this_turn.has(rune)


## How many times this tile card has activated so far this turn (includes the current one).
func get_tile_card_activation_count_this_turn(rune: TileCard) -> int:
	return _activated_tile_cards_this_turn.count(rune)

#endregion

#region Segment passive runtime

func get_current_turn_trigger_count() -> int:
	return _current_turn_trigger_count


func apply_active_segment_passives(character_id: String) -> void:
	_active_passives_by_segment.clear()
	var set_id := MetaProgressionManager.get_selected_set_id(character_id)
	var segments := MetaProgressionManager.get_segment_placements(character_id, set_id)
	for segment_key: String in segments.keys():
		var segment_index := int(segment_key)
		var passive_ids: Array = segments[segment_key]
		if not passive_ids is Array:
			continue
		var passives: Array[SegmentPassive] = []
		for entry in passive_ids:
			var passive := MetaProgressionManager.get_passive_by_id(String(entry))
			if passive != null:
				passives.append(passive)
		_active_passives_by_segment[segment_index] = passives
	passive_runtime.bind(_active_passives_by_segment)
	passive_runtime.reset_turn()


func get_passives_for_segment(segment_index: int) -> Array[SegmentPassive]:
	return passive_runtime.get_passives(segment_index)


## Score is Energy x Mult, rounded at the segment. Passives must already be on the cards.
func get_segment_turn_contribution_breakdown(
	_segment_index: int,
	energy: int,
	multiplier: float
) -> Dictionary:
	var contribution := int(round(float(energy) * multiplier))
	return {
		"display_energy": energy,
		"display_multiplier": multiplier,
		"contribution": contribution,
	}


func compute_segment_turn_contribution(segment_index: int, energy: int, multiplier: float) -> int:
	return int(
		get_segment_turn_contribution_breakdown(segment_index, energy, multiplier)["contribution"]
	)


func record_turn_segment_peaks(segment_contributions: Array[int]) -> void:
	for contribution in segment_contributions:
		_run_peak_segment_score_single_turn = maxi(_run_peak_segment_score_single_turn, contribution)
	_run_peak_triggers_single_turn = maxi(_run_peak_triggers_single_turn, _current_turn_trigger_count)


func record_peak_gold_held(amount: int) -> void:
	_run_peak_gold_held = maxi(_run_peak_gold_held, amount)


func mark_full_map_cards_achieved() -> void:
	_run_full_map_cards_achieved = true


func build_run_snapshot(is_win: bool) -> Dictionary:
	var character_id := selected_character.id if selected_character != null else ""
	return {
		"is_win": is_win,
		"character_id": character_id,
		"difficulty": int(selected_difficulty),
		"rounds_completed": current_round if is_win else maxi(0, current_round - 1),
		"peak_gold_held": _run_peak_gold_held,
		"gold_earned": GoldManager.total_earned_this_run,
		"peak_segment_score_single_turn": _run_peak_segment_score_single_turn,
		"peak_triggers_single_turn": _run_peak_triggers_single_turn,
		"full_map_cards": _run_full_map_cards_achieved,
	}


func clear_run_peak_tracking() -> void:
	_active_passives_by_segment.clear()
	passive_runtime.bind({})
	passive_runtime.reset_turn()
	_run_peak_triggers_single_turn = 0
	_run_peak_segment_score_single_turn = 0
	_run_peak_gold_held = 0
	_current_turn_trigger_count = 0
	_run_full_map_cards_achieved = false
	MetaProgressionManager.begin_run_tracking()

#endregion

func set_game_speed(speed: float) -> void:
	game_speed = speed
	GameSettings.set_game_speed(game_speed)


## Scene timer that stops while the pause menu freezes the tree.
## SceneTree.create_timer ignores pause unless process_always is false.
func create_pauseable_timer(duration: float) -> SceneTreeTimer:
	return get_tree().create_timer(duration, false)

#region tile card pool loading

## Recursively load every .tres rune under the runes folder, skipping duplicate ids.
## ResourceLoader.list_directory works in exported builds, DirAccess only sees .gd files in PCK.
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

		if _has_tile_card_with_id(rune.id):
			continue

		tile_cards_pool.append(rune)


func _has_tile_card_with_id(rune_id: String) -> bool:
	for existing_rune in tile_cards_pool:
		if existing_rune.id == rune_id:
			return true
	return false


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
	_total_rune_activations = 0
	_remaining_turns = MAX_TURNS_PER_ROUND
	_is_processing_turn = false
	required_score = ScoreProgression.get_required_score(current_round)
	_total_round_score = 0
	_turn_score = 0
	_activated_tile_cards_this_turn.clear()
	turn_stamp = 0
	game_speed = GameSettings.game_speed
	clear_run_peak_tracking()
	# Peak tracking clears the loadout. Re-apply the selected character's passives for this run.
	if selected_character != null:
		apply_active_segment_passives(selected_character.id)


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
	passive_runtime.reset_turn()
	EventBus.turn_started.emit()
	# No merchant visit precedes a debug jump, so the reveal plays right away.
	ChallengeManager.play_reveal()
	RunSaveManager.request_autosave()


func capture_run_state() -> Dictionary:
	return {
		"highest_round_score": highest_round_score,
		"current_round": current_round,
		"total_rune_activations": _total_rune_activations,
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
		"full_map_cards": _run_full_map_cards_achieved,
	}


func apply_run_state(state: Dictionary) -> void:
	current_round = int(state.get("current_round", 1))
	highest_round_score = int(state.get("highest_round_score", state.get("total_round_score", 0)))
	_total_rune_activations = int(state.get("total_rune_activations", 0))
	_remaining_turns = int(state.get("remaining_turns", MAX_TURNS_PER_ROUND))
	_is_processing_turn = false
	required_score = int(state.get("required_score", ScoreProgression.get_required_score(current_round)))
	_total_round_score = int(state.get("total_round_score", 0))
	_turn_score = int(state.get("turn_score", 0))
	turn_stamp = int(state.get("turn_stamp", 0))
	_activated_tile_cards_this_turn.clear()
	game_speed = float(state.get("game_speed", 1.0))
	_run_peak_gold_held = int(state.get("peak_gold_held", 0))
	_run_peak_segment_score_single_turn = int(state.get("peak_segment_score_single_turn", 0))
	_run_peak_triggers_single_turn = int(state.get("peak_triggers_single_turn", 0))
	_run_full_map_cards_achieved = bool(state.get("full_map_cards", false))
	# Continue does not go through reset_for_new_run, so re-bind the loadout.
	if selected_character != null:
		apply_active_segment_passives(selected_character.id)


func get_tile_card_by_id(rune_id: String) -> TileCard:
	for rune in tile_cards_pool:
		if rune.id == rune_id:
			return rune
	return null


#endregion
