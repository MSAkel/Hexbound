extends Control

@onready var played_as_label: Label = $background/StatsPanel/MarginContainer/VBoxContainer/PlayedAsLabel

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	hide()
	EventBus.game_ended.connect(_on_game_ended)
	played_as_label.text = GameManager.selected_character.display_name if GameManager.selected_character else "Unknown"


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")

func _on_game_ended() -> void:
	RunSaveManager.delete_save()
	UiManager.show_panel(self)
	AudioManager.play_sfx(UI_SOUNDS.GAME_OVER)
