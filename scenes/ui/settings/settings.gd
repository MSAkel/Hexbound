extends Control

signal closed

#@onready var master_volume_slider: HSlider = $Container/SettingsContainer/MasterVolume/HSlider
@onready var music_volume_slider: HSlider = $VBoxContainer/SettingsContainer/MusicVolume/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/SettingsContainer/SFXVolume/SFXVolumeSlider
@onready var game_speed_option_button: OptionButton = $VBoxContainer/SettingsContainer/GameSpeed/GameSpeedOptionButton

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

var main_menu_scene = load("res://scenes/ui/main_menu/main_menu.tscn")

func _ready() -> void:
	# Initialize sliders with current values
	#master_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	music_volume_slider.value = AudioManager.music_volume
	sfx_volume_slider.value = AudioManager.sfx_volume
	
	# Connect slider signals
	#master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

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
