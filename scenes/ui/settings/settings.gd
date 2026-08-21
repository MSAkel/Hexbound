extends Control

signal closed

#@onready var master_volume_slider: HSlider = $Container/SettingsContainer/MasterVolume/HSlider
@onready var music_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/MusicVolume/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/SFXVolume/SFXVolumeSlider
@onready var game_speed_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/GameSpeed/GameSpeedOptionButton
@onready var tutorial_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/TutorialContainer/TutorialCheckBox

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

var main_menu_scene = load("res://scenes/ui/main_menu/main_menu.tscn")

func _ready() -> void:
	# Initialize sliders with current values
	#master_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_volume_slider.value = AudioManager.music_volume
	sfx_volume_slider.value = AudioManager.sfx_volume
	_sync_tutorial_checkbox()
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect slider signals
	#master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)


func _on_visibility_changed() -> void:
	if visible:
		_sync_tutorial_checkbox()


func _sync_tutorial_checkbox() -> void:
	GameSettings.ensure_loaded()
	tutorial_check_box.set_pressed_no_signal(GameSettings.tutorial_enabled)

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

func _on_game_speed_option_button_item_selected(index: int) -> void:
	match index:
		0:
			GameManager.set_game_speed(1.0)
		1:
			GameManager.set_game_speed(2.0)
		2:
			GameManager.set_game_speed(3.0)
	

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	closed.emit()

func _on_back_button_mouse_entered() -> void:
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _on_v_sync_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on: 
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED) 
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _on_tutorial_check_box_toggled(toggled_on: bool) -> void:
	# Checked means the banner should appear on the next run, and immediately if a run is open.
	GameSettings.set_tutorial_enabled(toggled_on)
	# In-run banners listen on this group so the toggle can preview immediately.
	for banner in get_tree().get_nodes_in_group("tutorial_banner"):
		if banner.has_method("set_tutorial_visible_from_settings"):
			banner.set_tutorial_visible_from_settings(toggled_on)
