extends Control

const SOUNDTRACK := preload("res://scripts/soundtracks.gd")
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

var main_scene := load("res://scenes/main.tscn")
var main_menu_scene := load("res://scenes/ui/main_menu/main_menu.tscn")

@onready var selection_details: SelectionDetails = $Container/VBoxContainer/CharacterDetails

# One selection per character definition; only one is shown at a time.
var selections: Array[CharacterDefinition] = []
var current_index: int = 0


func _ready() -> void:
	get_tree().paused = false

	selections = PlayerCharacter.get_all_characters()
	selection_details.prev_selection_pressed.connect(_on_prev_selection)
	selection_details.next_selection_pressed.connect(_on_next_selection)
	_update_display()

	var music := SOUNDTRACK.get_music_for_scene(scene_file_path)
	if music:
		AudioManager.play_music(music)


func get_selected_character() -> CharacterDefinition:
	return selections[current_index]


func _on_prev_selection() -> void:
	current_index = (current_index - 1 + selections.size()) % selections.size()
	_update_display()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _on_next_selection() -> void:
	current_index = (current_index + 1) % selections.size()
	_update_display()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _update_display() -> void:
	# Character name, starting hand, and map details are shown inside SelectionDetails.
	selection_details.display_selection(get_selected_character())


func _on_start_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)

	# Character choice locks in layout rules for the entire run.
	GameManager.selected_character = get_selected_character()
	GameManager.selected_difficulty = selection_details.get_selected_difficulty()

	get_tree().change_scene_to_packed(main_scene)


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(main_menu_scene)
