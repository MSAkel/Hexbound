class_name GameSpeedUi
extends Control

@onready var regular_game_speed_button: Button = $GameSpeedContainer/RegularGameSpeedButton
@onready var double_game_speed_button: Button = $GameSpeedContainer/DoubleGameSpeedButton
@onready var triple_game_speed_button: Button = $GameSpeedContainer/TripleGameSpeedButton

func _on_regular_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(1.0)

func _on_double_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(2.0)

func _on_triple_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(3.0)
