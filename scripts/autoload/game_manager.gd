extends Node

## Central coordinator for run flow: turns, scoring, rounds, resource pools, and turn processing.

signal game_speed_changed(new_speed: float)

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
const SCORE_PROGRESSION := preload("res://resources/score_progression.tres")
## Number of runes in a rune pack, picked at the end of each turn
const RUNES_PACK_SIZE := 3
const MAX_TURNS_PER_ROUND := 5

var current_round: int = 1
## Counter for the number of triggers that have been activated throughout the run, used to reward perks
var _total_rune_activations: int = 0

var _activations_needed_for_next_perk: int = 2

var activations_needed_for_next_perk: int:
	get:
		return _activations_needed_for_next_perk
	set(value):
		_activations_needed_for_next_perk = value
		if _total_rune_activations >= _activations_needed_for_next_perk:
			_activations_needed_for_next_perk = _activations_needed_for_next_perk * 1.5
			EventBus.activations_needed_for_next_perk_changed.emit(_activations_needed_for_next_perk)

var total_rune_activations: int:
	get:
		return _total_rune_activations
	set(value):
		_total_rune_activations = value

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
var required_score: int = SCORE_PROGRESSION.get_required_score(1)

## total score earned in the current round. 
var _total_round_score: int = 0
## Score earned during the current turn
var _turn_score: int = 0

var total_round_score: int:
	get:
		return _total_round_score
	set(value):
		_total_round_score = value
		EventBus.total_round_score_changed.emit()

var turn_score: int:
	get:
		return _turn_score
	set(value):
		_turn_score = value
		EventBus.turn_score_changed.emit()

#endregion

#region Runes and enhancements pools

## Every rune resource loaded from disk at startup.
var tile_cards_pool: Array[TileCard] = []
## Every enhancement resource loaded from disk at startup.
var enhancements_pool: Array[Enhancement] = []

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
	GameSettings.ensure_loaded()
	game_speed = GameSettings.game_speed
	if selected_character == null:
		selected_character = PlayerCharacter.get_default_character()

	_load_tile_cards_from_directory("res://resources/tile_cards/")
	_load_enhancements_from_directory("res://resources/enhancements/")

	if tile_cards_pool.is_empty():
		push_error("No tile cards loaded into pool")

	if enhancements_pool.is_empty():
		push_warning("No enhancements loaded into pool")

	EventBus.turn_ended.connect(end_turn)
	EventBus.turn_started.connect(_on_turn_started)
#region Turn flow

func end_turn() -> void:
	_is_processing_turn = true


func finish_turn_processing() -> void:
	_is_processing_turn = false

	# A turn is only consumed when it failed to reach the round goal.
	var should_consume_turn := remaining_turns > 0 and total_round_score + turn_score < required_score

	total_round_score += turn_score
	turn_score = 0

	if _has_met_round_goal():
		_complete_current_round()
	else:
		UiManager.show_runes_choice_panel.emit()
		EventBus.turn_started.emit()

	if should_consume_turn:
		remaining_turns -= 1
		EventBus.turn_changed.emit()
		_check_run_loss()


func _on_turn_started() -> void:
	turn_stamp += 1
	_activated_tile_cards_this_turn.clear()
	GoldManager.reset_turn_tracking()


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


## Hands the completed round to RoundFlow, which owns every step up to the next turn.
## The summary screen reads remaining turns and gold earned, so nothing advances until Continue.
func _complete_current_round() -> void:
	GoldManager.apply_round_speed_rewards(
		get_skipped_turns(),
		remaining_turns
	)
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
	required_score = SCORE_PROGRESSION.get_required_score(current_round)
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

## Read rune activation to check if it has already fired this turn.
## Used by hex_tile_map.gd can_consume_next_tile_card_in_trigger_order()
func has_tile_card_activated_this_turn(rune: TileCard) -> bool:
	return _activated_tile_cards_this_turn.has(rune)


## How many times this tile card has activated so far this turn (includes the current one).
func get_tile_card_activation_count_this_turn(rune: TileCard) -> int:
	return _activated_tile_cards_this_turn.count(rune)

func rune_activations_countdown() -> int:
	return _activations_needed_for_next_perk - _total_rune_activations
#endregion

func set_game_speed(speed: float) -> void:
	game_speed = speed
	GameSettings.set_game_speed(game_speed)

#region tile cards and enhancement cards pool loading

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

#region Run save / load

func reset_for_new_run() -> void:
	RoundFlow.reset_for_new_run()
	current_round = 1
	_total_rune_activations = 0
	_remaining_turns = MAX_TURNS_PER_ROUND
	_is_processing_turn = false
	required_score = SCORE_PROGRESSION.get_required_score(current_round)
	_total_round_score = 0
	_turn_score = 0
	_activated_tile_cards_this_turn.clear()
	turn_stamp = 0
	game_speed = GameSettings.game_speed


## Moves a fresh run to a chosen round while keeping round-dependent state in sync.
func set_starting_round_for_debug(starting_round: int) -> void:
	current_round = maxi(1, starting_round)
	_apply_round_state()
	# No merchant visit precedes a debug start, so the reveal plays right away.
	ChallengeManager.play_reveal()


func capture_run_state() -> Dictionary:
	return {
		"current_round": current_round,
		"total_rune_activations": _total_rune_activations,
		"remaining_turns": _remaining_turns,
		"is_processing_turn": _is_processing_turn,
		"required_score": required_score,
		"total_round_score": _total_round_score,
		"turn_score": _turn_score,
		"turn_stamp": turn_stamp,
		"game_speed": _game_speed,
	}


func apply_run_state(state: Dictionary) -> void:
	current_round = int(state.get("current_round", 1))
	_total_rune_activations = int(state.get("total_rune_activations"))
	_remaining_turns = int(state.get("remaining_turns", MAX_TURNS_PER_ROUND))
	_is_processing_turn = bool(state.get("is_processing_turn", false))
	required_score = int(state.get("required_score", SCORE_PROGRESSION.get_required_score(current_round)))
	_total_round_score = int(state.get("total_round_score", 0))
	_turn_score = int(state.get("turn_score", 0))
	turn_stamp = int(state.get("turn_stamp", 0))
	_activated_tile_cards_this_turn.clear()
	game_speed = float(state.get("game_speed", 1.0))


func get_tile_card_by_id(rune_id: String) -> TileCard:
	for rune in tile_cards_pool:
		if rune.id == rune_id:
			return rune
	return null


func get_enhancement_by_id(enhancement_id: String) -> Enhancement:
	for enhancement in enhancements_pool:
		if enhancement.id == enhancement_id:
			return enhancement
	return null

#endregion
