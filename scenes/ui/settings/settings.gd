extends Control

signal closed

@onready var master_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/MasterVolume/HSlider
@onready var music_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/MusicVolume/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/SFXVolume/SFXVolumeSlider
@onready var game_speed_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/GameSpeed/GameSpeedOptionButton
@onready var screen_shake_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/ScreenShakeContainer/ScreenShakeCheckBox
@onready var display_mode_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/DisplayModeContainer/DisplayModeOptionButton
@onready var resolution_option_button: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/ResolutionContainer/ResolutionOptionButton
@onready var v_sync_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/VSyncContainer/VSyncCheckBox
@onready var tutorial_check_box: CheckBox = $VBoxContainer/ScrollContainer/SettingsContainer/TutorialContainer/TutorialCheckBox
@onready var back_button: Button = $VBoxContainer/BackButton

var _resolution_options: Array[Vector2i] = []

func _ready() -> void:
	# Initialize sliders with current values
	master_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_volume_slider.value = AudioManager.music_volume
	sfx_volume_slider.value = AudioManager.sfx_volume
	_populate_resolution_options()
	_sync_settings_controls()
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect slider signals
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)


func _on_visibility_changed() -> void:
	if visible:
		_sync_settings_controls()
		call_deferred("_focus_settings")


func _focus_settings() -> void:
	if not visible:
		return
	if back_button != null and not back_button.disabled:
		back_button.grab_focus()
		return
	MenuFocus.grab_first($VBoxContainer/ScrollContainer/SettingsContainer)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_button_pressed()


func _populate_resolution_options() -> void:
	GameSettings.ensure_loaded()
	_resolution_options.assign(GameSettings.RESOLUTIONS)
	resolution_option_button.clear()
	for resolution in _resolution_options:
		resolution_option_button.add_item("%dx%d" % [resolution.x, resolution.y])


func _sync_settings_controls() -> void:
	GameSettings.ensure_loaded()
	game_speed_option_button.select(GameSettings.preset_index_for_speed(GameSettings.game_speed))
	screen_shake_check_box.set_pressed_no_signal(GameSettings.screen_shake_enabled)
	v_sync_check_box.set_pressed_no_signal(GameSettings.vsync_enabled)
	display_mode_option_button.select(GameSettings.display_mode)
	var resolution_index := _resolution_options.find(GameSettings.resolution)
	resolution_option_button.select(resolution_index if resolution_index >= 0 else 0)
	# Resolution only applies in windowed mode. Grey it out otherwise.
	var resolution_enabled := GameSettings.display_mode == GameSettings.DISPLAY_MODE_WINDOWED
	resolution_option_button.disabled = not resolution_enabled
	tutorial_check_box.set_pressed_no_signal(GameSettings.tutorial_enabled)

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

func _on_game_speed_option_button_item_selected(index: int) -> void:
	var presets := GameSettings.GAME_SPEED_PRESETS
	var clamped_index := clampi(index, 0, presets.size() - 1)
	GameManager.set_game_speed(presets[clamped_index])
	

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	closed.emit()

func _on_back_button_mouse_entered() -> void:
	AudioManager.play_ui_hover()


func _on_v_sync_check_box_toggled(toggled_on: bool) -> void:
	GameSettings.set_vsync_enabled(toggled_on)


func _on_screen_shake_check_box_toggled(toggled_on: bool) -> void:
	GameSettings.set_screen_shake_enabled(toggled_on)


func _on_display_mode_option_button_item_selected(index: int) -> void:
	GameSettings.set_display_mode(index)
	_sync_settings_controls()


func _on_resolution_option_button_item_selected(index: int) -> void:
	if index >= 0 and index < _resolution_options.size():
		GameSettings.set_resolution(_resolution_options[index])


func _on_tutorial_check_box_toggled(toggled_on: bool) -> void:
	# Checked means the banner should appear on the next run, and immediately if a run is open.
	GameSettings.set_tutorial_enabled(toggled_on)
	# In-run banners listen on this group so the toggle can preview immediately.
	for banner in get_tree().get_nodes_in_group("tutorial_banner"):
		if banner.has_method("set_tutorial_visible_from_settings"):
			banner.set_tutorial_visible_from_settings(toggled_on)
