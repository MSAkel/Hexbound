extends Node

## Central coordinator for run flow: turns, scoring, phases, resource pools, and turn processing.

signal game_speed_changed(new_speed: float)

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
## Number of runes in a rune pack, picked at the end of each turn
const RUNES_PACK_SIZE := 3
const MAX_TURNS_PER_PHASE := 5

## Set when a turn ends with enough score to meet the phase goal
var _pending_merchant_visit := false
## Score from the phase just completed, kept for the phase-complete screen after total_round_score resets.
## TODO: reconsider when the next phase starts?
var completed_phase_score: int = 0
## After the final-challenge victory screen, rune pick and merchant happen before phase 13.
var _pending_post_victory_phase_advance := false

var current_phase: int = 1
## Counter for the number of triggers that have been activated throughout the run, used to reward perks
var trigger_counter: int = 0

#region Turn state
## Remaining turns in the current phase (counts down from get_max_turns_per_phase()).
var _remaining_turns := MAX_TURNS_PER_PHASE
## Blocks player input while runes are resolving after end turn.
var _is_processing_turn := false

var remaining_turns: int:
	get:
		return _remaining_turns
	set(value):
		_remaining_turns = value
		# Hitting 0 remaining after a failed turn ends the run.
		if _remaining_turns <= 0:
			EventBus.game_ended.emit()

var is_processing_turn: bool:
	get:
		return _is_processing_turn

#endregion

#region Score and phase progression

## Score needed to complete the current phase and open the merchant.
var required_score: int = 1000
## Applied each time required_score is met to scale difficulty across phases.
var required_score_multiplier: int = 1.5

## total score earned in the current round/phase. 
## TOOD: Need name consistency with either round or phase.
var _total_round_score: int = 0
## Score earned during the current turn
var _turn_score: int = 0

var total_round_score: int:
	get:
		return _total_round_score
	set(value):
		_total_round_score = value
		EventBus.total_round_score_changed.emit()
		if _total_round_score >= required_score:
			_complete_current_phase()

var turn_score: int:
	get:
		return _turn_score
	set(value):
		_turn_score = value
		EventBus.turn_score_changed.emit()

#endregion

#region Runes and enhancements pools

## Every rune resource loaded from disk at startup.
var runes_pool: Array[Rune] = []
## Every enhancement resource loaded from disk at startup.
var enhancements_pool: Array[Enhancement] = []

#endregion

#region Rune activation tracking

## Cleared at turn start, filled as each rune resolves during turn processing.
var _runes_activated_this_turn: int = 0
var _activated_runes_this_turn: Array[Rune] = []
## Incremented on each turn_started; placed runes use this to gate once-per-turn permanent effects.
var turn_stamp: int = 0

#endregion

#region Character selection

## Chosen on the character selection screen; drives layout rules, starting hand, and passives.
var selected_character: CharacterDefinition = null
var selected_difficulty: Difficulty.Level = Difficulty.Level.LEVEL_0

#endregion

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
	if selected_character == null:
		selected_character = PlayerCharacter.get_default_character()

	_load_runes_from_directory("res://resources/runes/")
	_load_enhancements_from_directory("res://resources/enhancements/")

	if runes_pool.is_empty():
		push_error("No runes loaded into pool")

	if enhancements_pool.is_empty():
		push_warning("No enhancements loaded into pool")

	EventBus.turn_ended.connect(end_turn)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.merchant_closed.connect(_on_merchant_closed)
#region Turn flow

func end_turn() -> void:
	_is_processing_turn = true


func finish_turn_processing() -> void:
	_is_processing_turn = false

	## Score the turn before advancing counters so phase logic sees this turn's contribution.
	var pending_total_round_score := total_round_score + turn_score
	# Consume one remaining turn when the phase goal was not met.
	var should_consume_turn := remaining_turns > 0 and pending_total_round_score < required_score

	if pending_total_round_score >= required_score:
		if ChallengeManager.is_completing_final_challenge_phase():
			total_round_score = pending_total_round_score
			turn_score = 0
			EventBus.turn_started.emit()
			return
		_pending_merchant_visit = true
		# Snapshot before _complete_current_phase resets total_round_score to 0.
		completed_phase_score = pending_total_round_score

	total_round_score = pending_total_round_score
	turn_score = 0

	# Phase complete → rune pick → merchant when the phase goal was met, rune pick only otherwise.
	if _pending_merchant_visit:
		UiManager.show_phase_complete_panel.emit()
	else:
		UiManager.show_runes_choice_panel.emit()
	EventBus.turn_started.emit()

	if should_consume_turn:
		remaining_turns -= 1
		EventBus.turn_changed.emit()


func _on_turn_started() -> void:
	turn_stamp += 1
	_runes_activated_this_turn = 0
	_activated_runes_this_turn.clear()
	GoldManager.reset_turn_tracking()


func consume_pending_merchant_visit() -> bool:
	if not _pending_merchant_visit:
		return false
	_pending_merchant_visit = false
	return true


func is_in_post_victory_transition() -> bool:
	return _pending_post_victory_phase_advance


func continue_run_after_victory() -> void:
	_pending_merchant_visit = true
	_pending_post_victory_phase_advance = true
	# Choice of cards at the end of the turn
	UiManager.show_runes_choice_panel.emit()
	EventBus.turn_started.emit()


func _on_merchant_closed() -> void:
	if not _pending_post_victory_phase_advance:
		return

	_pending_post_victory_phase_advance = false
	advance_phase()
	EventBus.turn_started.emit()


func get_max_turns_per_phase() -> int:
	return ChallengeManager.get_max_turns_per_phase()


## Ascending turn index within the phase (1 on the first turn, max on the last).
## Use when effects scale with how far into the phase you are, not remaining turns.
func get_turn_number() -> int:
	return get_max_turns_per_phase() - remaining_turns + 1


func _complete_current_phase() -> void:
	required_score = required_score * required_score_multiplier + 750
	total_round_score = 0
	EventBus.required_score_changed.emit()

	if ChallengeManager.is_completing_final_challenge_phase():
		EventBus.challenge_banner_hidden.emit()
		EventBus.all_challenges_completed.emit()
		return

	advance_phase()


func advance_phase() -> void:
	current_phase += 1
	GoldManager.add(20)
	AudioManager.play_sfx(UI_SOUNDS.GOLD_GAINED)

	# Apply challenge first so Rush Hour's reduced max is reflected in remaining turns.
	ChallengeManager.on_phase_advanced(current_phase)
	remaining_turns = get_max_turns_per_phase()
	EventBus.turn_changed.emit()
	EventBus.phase_changed.emit(current_phase)
	EventBus.required_score_changed.emit()

#endregion

#region Rune activation API

func get_runes_activated_this_turn() -> int:
	return _runes_activated_this_turn


func has_rune_activated_this_turn(rune: Rune) -> bool:
	return _activated_runes_this_turn.has(rune)


func register_rune_activation(rune: Rune) -> void:
	_runes_activated_this_turn += 1
	_activated_runes_this_turn.append(rune)

#endregion

#region Runes and enhancements pool loading

## Recursively load every .tres rune under the runes folder, skipping duplicate ids.
## ResourceLoader.list_directory works in exported builds, DirAccess only sees .gd files in PCK.
func _load_runes_from_directory(dir_path: String) -> void:
	var normalized_path := dir_path
	if not normalized_path.ends_with("/"):
		normalized_path += "/"

	for entry in ResourceLoader.list_directory(normalized_path):
		if entry == "./" or entry == "../":
			continue

		if entry.ends_with("/"):
			# Visit subfolders first so organized copies win over legacy root duplicates.
			_load_runes_from_directory(normalized_path.path_join(entry.trim_suffix("/")))
			continue

		if not entry.ends_with(".tres"):
			continue

		var resource_path := normalized_path.path_join(entry)
		var rune := ResourceLoader.load(resource_path) as Rune
		if rune == null:
			push_error("Failed to load rune: " + resource_path)
			continue

		if _has_rune_with_id(rune.id):
			continue

		runes_pool.append(rune)


func _has_rune_with_id(rune_id: String) -> bool:
	for existing_rune in runes_pool:
		if existing_rune.id == rune_id:
			return true
	return false


## Load every .tres enhancement under the enhancements folder, skipping duplicate ids.
func _load_enhancements_from_directory(dir_path: String) -> void:
	var normalized_path := dir_path
	if not normalized_path.ends_with("/"):
		normalized_path += "/"

	for entry in ResourceLoader.list_directory(normalized_path):
		if entry == "./" or entry == "../":
			continue

		if entry.ends_with("/"):
			_load_enhancements_from_directory(normalized_path.path_join(entry.trim_suffix("/")))
			continue

		if not entry.ends_with(".tres"):
			continue

		var resource_path := normalized_path.path_join(entry)
		var enhancement := ResourceLoader.load(resource_path) as Enhancement
		if enhancement == null:
			push_error("Failed to load enhancement: " + resource_path)
			continue

		if _has_enhancement_with_id(enhancement.id):
			continue

		enhancements_pool.append(enhancement)


func _has_enhancement_with_id(enhancement_id: String) -> bool:
	for existing_enhancement in enhancements_pool:
		if existing_enhancement.id == enhancement_id:
			return true
	return false

#endregion

func set_game_speed(speed: float) -> void:
	game_speed = speed


#region Run save / load

func reset_for_new_run() -> void:
	current_phase = 1
	trigger_counter = 0
	_pending_merchant_visit = false
	completed_phase_score = 0
	_pending_post_victory_phase_advance = false
	_remaining_turns = MAX_TURNS_PER_PHASE
	_is_processing_turn = false
	required_score = 1000
	required_score_multiplier = 1.5
	_total_round_score = 0
	_turn_score = 0
	_runes_activated_this_turn = 0
	_activated_runes_this_turn.clear()
	turn_stamp = 0
	game_speed = 1.0


func capture_run_state() -> Dictionary:
	return {
		"current_phase": current_phase,
		"trigger_counter": trigger_counter,
		"remaining_turns": _remaining_turns,
		"is_processing_turn": _is_processing_turn,
		"required_score": required_score,
		"required_score_multiplier": required_score_multiplier,
		"total_round_score": _total_round_score,
		"turn_score": _turn_score,
		"pending_merchant_visit": _pending_merchant_visit,
		"completed_phase_score": completed_phase_score,
		"pending_post_victory_phase_advance": _pending_post_victory_phase_advance,
		"turn_stamp": turn_stamp,
		"game_speed": _game_speed,
	}


func apply_run_state(state: Dictionary) -> void:
	current_phase = int(state.get("current_phase", 1))
	trigger_counter = int(state.get("trigger_counter", 0))
	_remaining_turns = int(state.get("remaining_turns", MAX_TURNS_PER_PHASE))
	_is_processing_turn = bool(state.get("is_processing_turn", false))
	required_score = int(state.get("required_score", 1000))
	required_score_multiplier = state.get("required_score_multiplier", 1.5)
	_total_round_score = int(state.get("total_round_score", 0))
	_turn_score = int(state.get("turn_score", 0))
	_pending_merchant_visit = bool(state.get("pending_merchant_visit", false))
	completed_phase_score = int(state.get("completed_phase_score", 0))
	_pending_post_victory_phase_advance = bool(state.get("pending_post_victory_phase_advance", false))
	turn_stamp = int(state.get("turn_stamp", 0))
	_runes_activated_this_turn = 0
	_activated_runes_this_turn.clear()
	game_speed = float(state.get("game_speed", 1.0))


func get_rune_by_id(rune_id: String) -> Rune:
	for rune in runes_pool:
		if rune.id == rune_id:
			return rune
	return null


func get_enhancement_by_id(enhancement_id: String) -> Enhancement:
	for enhancement in enhancements_pool:
		if enhancement.id == enhancement_id:
			return enhancement
	return null

#endregion
