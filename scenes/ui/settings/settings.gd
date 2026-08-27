extends Control

signal closed

#@onready var master_volume_slider: HSlider = $Container/SettingsContainer/MasterVolume/HSlider
@onready var music_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/MusicVolume/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/SFXVolume/SFXVolumeSlider
@onready var game_speed_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/GameSpeed/GameSpeedOptionButton
@onready var screen_shake_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/ScreenShakeContainer/ScreenShakeCheckBox
@onready var display_mode_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/DisplayModeContainer/DisplayModeOptionButton
@onready var resolution_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/ResolutionContainer/ResolutionOptionButton
@onready var v_sync_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/VSyncContainer/VSyncCheckBox
@onready var tutorial_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/TutorialContainer/TutorialCheckBox

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")
const RESOLUTIONS := [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

func _ready() -> void:
	# Initialize sliders with current values
	#master_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_volume_slider.value = AudioManager.music_volume
	sfx_volume_slider.value = AudioManager.sfx_volume
	_sync_settings_controls()
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect slider signals
	#master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)


func _on_visibility_changed() -> void:
	if visible:
		_sync_settings_controls()


func _sync_settings_controls() -> void:
	GameSettings.ensure_loaded()
	game_speed_option_button.select(clampi(roundi(GameSettings.game_speed) - 1, 0, 2))
	screen_shake_check_box.set_pressed_no_signal(GameSettings.screen_shake_enabled)
	v_sync_check_box.set_pressed_no_signal(GameSettings.vsync_enabled)
	display_mode_option_button.select(GameSettings.display_mode)
	var resolution_index := RESOLUTIONS.find(GameSettings.resolution)
	resolution_option_button.select(resolution_index if resolution_index >= 0 else 4)
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
	GameSettings.set_vsync_enabled(toggled_on)


func _on_screen_shake_check_box_toggled(toggled_on: bool) -> void:
	GameSettings.set_screen_shake_enabled(toggled_on)


func _on_display_mode_option_button_item_selected(index: int) -> void:
	GameSettings.set_display_mode(index)
	_sync_settings_controls()


func _on_resolution_option_button_item_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		GameSettings.set_resolution(RESOLUTIONS[index])


func _on_tutorial_check_box_toggled(toggled_on: bool) -> void:
	# Checked means the banner should appear on the next run, and immediately if a run is open.
	GameSettings.set_tutorial_enabled(toggled_on)
	# In-run banners listen on this group so the toggle can preview immediately.
	for banner in get_tree().get_nodes_in_group("tutorial_banner"):
		if banner.has_method("set_tutorial_visible_from_settings"):
			banner.set_tutorial_visible_from_settings(toggled_on)
