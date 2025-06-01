extends Control

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")
const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

var boons_selection_scene = load("res://scenes/ui/boons_selection/boons_selection.tscn")
var settings_scene = load("res://scenes/ui/settings/settings.tscn")

func _ready() -> void:
	# On game ending will pause the game, so we need to unpausse it
	get_tree().paused = false
	
	# Play main menu music
	var music = SOUNDTRACK.get_music_for_scene(scene_file_path)
	if music:
		AudioManager.play_music(music)
	
	# Connect button hover/focus signals
	for button in $Container/MenuItemsContainer.get_children():
		if button is Button:
			button.mouse_entered.connect(_on_button_hover)
			button.focus_entered.connect(_on_focus_entered)

func _on_button_hover() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.SELECT)

func _on_focus_entered() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.SELECT)

func _on_continue_pressed() -> void:
	pass # Replace with function body.


func _on_play_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(boons_selection_scene)


func _on_options_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(settings_scene)


func _on_exit_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	get_tree().quit()
