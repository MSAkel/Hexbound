extends Control

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

@onready var pause_menu: Control = $"."

func _on_continue_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	pause_menu.hide()


func _on_options_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)

func _on_main_menu_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	

func _on_exit_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if pause_menu.visible:
			pause_menu.hide()
			return
		pause_menu.show()
