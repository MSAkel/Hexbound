extends Control

const SOUNDTRACK := preload("res://scripts/soundtracks.gd")
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

var main_scene := load("res://scenes/main.tscn")
var main_menu_scene := load("res://scenes/ui/main_menu/main_menu.tscn")

@onready var the_peasant: VBoxContainer = $Container/Character/CharactersContainer/ThePeasant
@onready var the_greedy_lord: VBoxContainer = $Container/Character/CharactersContainer/TheGreedyLord

# Maps each character type to its selectable container
var character_containers: Dictionary = {}
# Only one character can be selected at a time
var selected_character: PlayerCharacter.Type = PlayerCharacter.Type.PEASANT

const SELECTED_COLOR := Color(0.8, 1.0, 0.8)
const UNSELECTED_COLOR := Color.WHITE


func _ready() -> void:
	get_tree().paused = false

	character_containers = {
		PlayerCharacter.Type.PEASANT: the_peasant,
		PlayerCharacter.Type.GREEDY_LORD: the_greedy_lord,
	}

	# Allow clicking each character panel to select it
	for character_type: PlayerCharacter.Type in character_containers:
		var container: VBoxContainer = character_containers[character_type]
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.gui_input.connect(_on_character_gui_input.bind(character_type))

	update_visuals()

	var music := SOUNDTRACK.get_music_for_scene(scene_file_path)
	if music:
		AudioManager.play_music(music)


func _on_character_gui_input(event: InputEvent, character_type: PlayerCharacter.Type) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		select_character(character_type)
		AudioManager.play_ui_sound(UI_SOUNDS.SELECT)


func select_character(character_type: PlayerCharacter.Type) -> void:
	selected_character = character_type
	update_visuals()


# Highlight the selected character's container and reset the others
func update_visuals() -> void:
	for character_type: PlayerCharacter.Type in character_containers:
		var container: VBoxContainer = character_containers[character_type]
		container.modulate = SELECTED_COLOR if character_type == selected_character else UNSELECTED_COLOR


func _on_start_button_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	# Persist the choice so gameplay systems (like the hand) can read it
	GameManager.selected_character = selected_character
	get_tree().change_scene_to_packed(main_scene)


func _on_back_button_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(main_menu_scene)
