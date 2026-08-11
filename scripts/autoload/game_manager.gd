extends Node

## Central coordinator for run flow: turns, scoring, phases, resource pools, and turn processing.

signal game_speed_changed(new_speed: float)

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
const RUNES_PACK_SIZE := 3
const MAX_TURNS_PER_PHASE := 5

## Set when a turn ends with enough score to meet the phase goal
var _pending_merchant_visit := false
## After the final-challenge victory screen, rune pick and merchant happen before phase 13.
var _pending_post_victory_phase_advance := false

var current_phase: int = 1

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
			Events.game_ended.emit()

var is_processing_turn: bool:
	get:
		return _is_processing_turn

#endregion

#region Score and phase progression

## Score needed to complete the current phase and open the merchant.
var required_score: int = 1500
## Applied each time required_score is met to scale difficulty across phases.
var required_score_multiplier: int = 2

var _total_round_score: int = 0
var _turn_score: int = 0
var _turn_multiplier: int = 1

var total_round_score: int:
	get:
		return _total_round_score
	set(value):
		_total_round_score = value
		Events.total_round_score_changed.emit()
		if _total_round_score >= required_score:
			_complete_current_phase()

var turn_score: int:
	get:
		return _turn_score
	set(value):
		_turn_score = value
		Events.turn_score_changed.emit()

var turn_multiplier: int:
	get:
		return _turn_multiplier
	set(value):
		_turn_multiplier = value
		Events.turn_multiplier_changed.emit()

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

#region Character and trigger order

## Chosen on the character selection screen, drives starting hand and trigger order.
var selected_character: PlayerCharacter.Type = PlayerCharacter.Type.SURVEYOR
var selected_difficulty: Difficulty.Level = Difficulty.Level.LEVEL_0
var _trigger_order: TriggerOrderType.Type = TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT

var trigger_order: TriggerOrderType.Type:
	get:
		return _trigger_order
	set(value):
		if _trigger_order == value:
			return
		_trigger_order = value
		Events.trigger_order_changed.emit(_trigger_order)

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
	_load_runes_from_directory("res://resources/runes/")
	_load_enhancements_from_directory("res://resources/enhancements/")

	if runes_pool.is_empty():
		push_error("No runes loaded into pool")

	if enhancements_pool.is_empty():
		push_warning("No enhancements loaded into pool")

	Events.turn_ended.connect(end_turn)
	Events.turn_started.connect(_on_turn_started)
	Events.merchant_closed.connect(_on_merchant_closed)
#region Turn flow

func end_turn() -> void:
	_is_processing_turn = true


func finish_turn_processing() -> void:
	_is_processing_turn = false

	## Score the turn before advancing counters so phase logic sees this turn's contribution.
	var pending_total_round_score := total_round_score + (turn_score * turn_multiplier)
	# Consume one remaining turn when the phase goal was not met.
	var should_consume_turn := remaining_turns > 0 and pending_total_round_score < required_score

	if pending_total_round_score >= required_score:
		if ChallengeManager.is_completing_final_challenge_phase():
			total_round_score = pending_total_round_score
			turn_score = 0
			turn_multiplier = 1
			Events.turn_started.emit()
			return
		_pending_merchant_visit = true

	total_round_score = pending_total_round_score
	turn_score = 0
	turn_multiplier = 1

	UiManager.show_runes_choice_panel.emit()
	Events.turn_started.emit()

	if should_consume_turn:
		remaining_turns -= 1
		Events.turn_changed.emit()


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
	Events.turn_started.emit()


func _on_merchant_closed() -> void:
	if not _pending_post_victory_phase_advance:
		return

	_pending_post_victory_phase_advance = false
	advance_phase()
	Events.turn_started.emit()


func get_max_turns_per_phase() -> int:
	return ChallengeManager.get_max_turns_per_phase()


## Ascending turn index within the phase (1 on the first turn, max on the last).
## Use when effects scale with how far into the phase you are, not remaining turns.
func get_turn_number() -> int:
	return get_max_turns_per_phase() - remaining_turns + 1


func _complete_current_phase() -> void:
	required_score = required_score * required_score_multiplier + 750
	total_round_score = 0
	Events.required_score_changed.emit()

	if ChallengeManager.is_completing_final_challenge_phase():
		Events.challenge_banner_hidden.emit()
		Events.all_challenges_completed.emit()
		return

	advance_phase()


func advance_phase() -> void:
	current_phase += 1
	GoldManager.add(20)
	AudioManager.play_sfx(UI_SOUNDS.GOLD_GAINED)

	# Apply challenge first so Rush Hour's reduced max is reflected in remaining turns.
	ChallengeManager.on_phase_advanced(current_phase)
	remaining_turns = get_max_turns_per_phase()
	Events.turn_changed.emit()
	Events.phase_changed.emit(current_phase)
	Events.required_score_changed.emit()

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
