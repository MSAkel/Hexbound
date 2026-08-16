extends Control

const SOUNDTRACK := preload("res://scripts/soundtracks.gd")
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

var main_scene := load("res://scenes/main.tscn")
var main_menu_scene := load("res://scenes/ui/main_menu/main_menu.tscn")

@onready var character_details: CharacterDetails = $Container/VBoxContainer/CharacterDetails

# One selection per character definition; only one is shown at a time.
var selections: Array[CharacterDefinition] = []
var current_index: int = 0


func _ready() -> void:
	get_tree().paused = false

	selections = PlayerCharacter.get_all_characters()
	character_details.prev_selection_pressed.connect(_on_prev_selection)
	character_details.next_selection_pressed.connect(_on_next_selection)

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
	# Name, passives, trigger order, and difficulty are shown inside CharacterDetails.
	character_details.display_selection(get_selected_character())

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(main_menu_scene)
