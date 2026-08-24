extends Control

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")
const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

# Subtle hover pop: slight grow + warm brighten
const HOVER_SCALE := Vector2(1.06, 1.06)
const HOVER_MODULATE := Color(1.2, 1.15, 1.05, 1.0)
const HOVER_DURATION := 0.12

@onready var game_version: Label = $GameVersion
@onready var menu_container: MarginContainer = $MenuContainer
@onready var settings_container: PanelContainer = $SettingsContainer
@onready var continue_button: Button = $MenuContainer/MenuItemsContainer/ContinueButton

var main_scene := load("res://scenes/main.tscn")


var character_selection_screen = load("res://scenes/ui/character_selection_screen/character_selection_screen.tscn")
var settings_scene = load("res://scenes/ui/settings/settings.tscn")

# Tracks in-flight hover tweens so rapid enter/exit does not stack.
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	# On game ending will pause the game, so we need to unpausse it
	get_tree().paused = false
	game_version.text = ProjectSettings.get_setting("application/config/version")
	_refresh_continue_button()
	
	# Play main menu music
	var music = SOUNDTRACK.get_music_for_scene(scene_file_path)
	if music:
		AudioManager.play_music(music)
	
	# Connect button hover/focus signals and scale from button center
	for button in $MenuContainer/MenuItemsContainer.get_children():
		if button is Button:
			button.pivot_offset = button.size / 2.0
			button.resized.connect(_on_button_resized.bind(button))
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))
			button.focus_entered.connect(_on_focus_entered)
	
	settings_container.closed.connect(_on_settings_closed)


func _on_button_resized(button: Button) -> void:
	# Keep scale origin centered when layout settles or size changes.
	button.pivot_offset = button.size / 2.0


func _on_button_hover(button: Button) -> void:
	AudioManager.play_sfx(UI_SOUNDS.SELECT)
	_animate_button_hover(button, true)


func _on_button_unhover(button: Button) -> void:
	_animate_button_hover(button, false)


func _animate_button_hover(button: Button, hovered: bool) -> void:
	# Cancel any previous tween on this button so enters/exits stay snappy.
	if _hover_tweens.has(button):
		var previous: Tween = _hover_tweens[button]
		if previous.is_valid():
			previous.kill()
	
	button.pivot_offset = button.size / 2.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(button, "scale", HOVER_SCALE if hovered else Vector2.ONE, HOVER_DURATION)
	tween.tween_property(button, "modulate", HOVER_MODULATE if hovered else Color.WHITE, HOVER_DURATION)
	_hover_tweens[button] = tween


func _on_focus_entered() -> void:
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _refresh_continue_button() -> void:
	continue_button.disabled = not RunSaveManager.has_save()


func _on_continue_pressed() -> void:
	if not RunSaveManager.has_save():
		return
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	RunSaveManager.request_continue_run()
	get_tree().change_scene_to_packed(main_scene)


func _on_play_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(character_selection_screen)


func _on_options_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	menu_container.hide()
	settings_container.show()

func _on_settings_closed() -> void:
	settings_container.hide()
	menu_container.show()

func _on_exit_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().quit()


func _on_collection_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/collection/collection.tscn")
