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
# Runes that are currently active on the map
# var active_runes: Array[Rune] = []

var selected_boons: Array[Boon] = []
# Character chosen on the character selection screen; affects starting hand
var selected_character: PlayerCharacter.Type = PlayerCharacter.Type.PEASANT

var influence_required: float = 100
var influence_required_multiplier: float = 1.75
var _influence_progress: float = 0

# Spendable gold for rune activation, rerolls, and quest delivery.
var _gold: int = 0

# Core game state getters and setters
var influence_progress: float:
	get:
		return _influence_progress
	set(value):
		_influence_progress = value
		Events.influence_changed.emit()
		if _influence_progress >= influence_required:
			influence_required = influence_required * influence_required_multiplier + 100
		#TODO: Make something happen once influence required is reached. Signal => event => something happens.

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


func _ready() -> void:
	# Load runes from the resources directory.
	const RUNES_DIR := "res://resources/runes/"
	for file_name in ResourceLoader.list_directory(RUNES_DIR):
		if file_name.ends_with("/"):
			continue
		if file_name.ends_with(".tres"):
			var rune := ResourceLoader.load(RUNES_DIR.path_join(file_name)) as Rune
			if rune:
				runes_pool.append(rune)
			else:
				push_error("Failed to load rune: " + file_name)
		
	if runes_pool.size() > 0:
		create_runes_pack()
	else:
		push_error("No runes loaded into pool")

	Events.turn_ended.connect(end_turn)

func end_turn() -> void:
	_is_processing_turn = true

func finish_turn_processing() -> void:
	_is_processing_turn = false
	_current_year += 1
	available_runes_packs += 1
	UiManager.show_runes_choice_panel.emit()
	Events.turn_started.emit()

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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		Events.turn_ended.emit()
		AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)
