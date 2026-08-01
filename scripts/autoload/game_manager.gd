extends Node

signal game_speed_changed(new_speed: float)

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")


var _current_year := 1
var _game_speed: float = 1.0
# Block input processing while turn is being processed
var _is_processing_turn: bool = false  

# All runes available in the game
var runes_pool: Array[Rune] = []
# Runes available for selection on the runes selection menu
var runes_pack: Array[Rune] = []
# increment by 1 on turn end
var _available_runes_packs: int = 0
var _runes_reroll_cost: int = 0

# Character chosen on the character selection screen; affects starting hand
var selected_character: PlayerCharacter.Type = PlayerCharacter.Type.SURVEYOR

# Required score to advance to the next phase
var required_score: int = 100
# Multiplier for required score once required score is reached
var required_score_multiplier: int = 2
# Total score accumulated during the game
var _total_score: int = 0

# Score accumulated during the current turn
var _turn_score: int = 0
# Multiplier for turn score
var _turn_multi: int = 1

# Spendable gold for rune activation, rerolls, and quest delivery.
var _gold: int = 0

# Resets when a new turn begins; incremented as each rune activates during turn processing.
var _runes_activated_this_turn: int = 0
var _activated_runes_this_turn: Array[Rune] = []

# Which tile order runes activate in when a turn ends.
var _trigger_order: TriggerOrderType.Type = TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT

# Core game state getters and setters
var turn_score: int:
	get:
		return _turn_score
	set(value):
		_turn_score = value
		Events.turn_score_changed.emit()
		
var turn_multi: int:
	get:
		return _turn_multi
	set(value):
		_turn_multi = value
		Events.turn_multi_changed.emit()

var total_score: int:
	get:
		return _total_score
	set(value):
		_total_score = value
		Events.total_score_changed.emit()
		if _total_score >= required_score:
			required_score = required_score * required_score_multiplier + 100
			Events.required_score_changed.emit()
		#TODO: Make something happen once score required is reached. Signal => event => something happens.

var current_year: int:
	get:
		return _current_year
	set(value):
		_current_year = max(1, value)

var game_speed: float:
	get:
		return _game_speed
	set(value):
		_game_speed = clamp(value, 1, 3.0)  # Limit speed between 1x and 3x
		game_speed_changed.emit(_game_speed)

# Runes
var available_runes_packs: int:
	get:
		return _available_runes_packs
	set(value):
		_available_runes_packs = max(0, value)
		Events.rune_pack_count_changed.emit()

var runes_reroll_cost: int:
	get:
		return _runes_reroll_cost
	set(value):
		_runes_reroll_cost = max(0, value)

# Add a getter for the processing state
var is_processing_turn: bool:
	get:
		return _is_processing_turn

var trigger_order: TriggerOrderType.Type:
	get:
		return _trigger_order
	set(value):
		if _trigger_order == value:
			return
		_trigger_order = value
		Events.trigger_order_changed.emit(_trigger_order)

func _ready() -> void:
	# Load every rune resource under the runes folder, including nested category folders.
	_load_runes_from_directory("res://resources/runes/")

	if runes_pool.size() > 0:
		create_runes_pack()
	else:
		push_error("No runes loaded into pool")

	Events.turn_ended.connect(end_turn)
	Events.turn_started.connect(_on_turn_started)

# Walk nested rune folders and add each .tres resource to the global pool.
func _load_runes_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Failed to open runes directory: " + dir_path)
		return

	# Subfolders first so organized copies win if legacy root duplicates still exist.
	for subdir in dir.get_directories():
		_load_runes_from_directory(dir_path.path_join(subdir))

	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue

		var resource_path := dir_path.path_join(file_name)
		var rune := ResourceLoader.load(resource_path) as Rune
		if rune == null:
			push_error("Failed to load rune: " + resource_path)
			continue

		if _has_rune_with_id(rune.id):
			continue

		runes_pool.append(rune)

# Check if a rune with the given id is already in the pool
func _has_rune_with_id(rune_id: String) -> bool:
	for existing_rune in runes_pool:
		if existing_rune.id == rune_id:
			return true
	return false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		Events.turn_ended.emit()
		AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)

#region Gold
func reset_gold() -> void:
	_gold = PlayerCharacter.get_starting_gold(selected_character)
	Events.gold_changed.emit(_gold)


func get_gold() -> int:
	return _gold


func add_gold(amount: int) -> void:
	_gold += amount
	Events.gold_changed.emit(_gold)


func remove_gold(amount: int) -> void:
	_gold -= amount
	Events.gold_changed.emit(_gold)
#endregion Gold

func end_turn() -> void:
	_is_processing_turn = true

func finish_turn_processing() -> void:
	_is_processing_turn = false
	total_score = total_score + (turn_score * turn_multi)
	# Reset turn score and multiplier
	turn_score = 0
	turn_multi = 1

	_current_year += 1
	available_runes_packs += 1
	UiManager.show_runes_choice_panel.emit()
	Events.turn_started.emit()


func _on_turn_started() -> void:
	_runes_activated_this_turn = 0
	_activated_runes_this_turn.clear()


func get_runes_activated_this_turn() -> int:
	return _runes_activated_this_turn


func has_rune_activated_this_turn(rune: Rune) -> bool:
	return _activated_runes_this_turn.has(rune)


func register_rune_activation(rune: Rune) -> void:
	_runes_activated_this_turn += 1
	_activated_runes_this_turn.append(rune)

# This function is called when the turn ends.
# it will go through the runes list and randomly select 3 runes to be available for selection
# Can be stacked on ending turn without selecting a rune
func create_runes_pack() -> void:
	if runes_pack.size() == 0:
		var shuffled_pool := runes_pool.duplicate()
		shuffled_pool.shuffle()

		for i in 3:
			runes_pack.append(shuffled_pool[i])

func set_game_speed(speed: float) -> void:
	_game_speed = speed
	game_speed_changed.emit(_game_speed)
