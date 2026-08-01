class_name GameSpeedUi
extends Control

func _on_regular_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(1.0)
	print("Regular game speed")

func _on_double_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(2.0)
	print("Double game speed")

func _on_triple_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(3.0)
	print("Triple game speed")
