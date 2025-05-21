extends Control

const BOONS_SELECTION_SCENE = preload("res://scenes/ui/boons_selection/boons_selection.tscn")

func _ready() -> void:
	# On game ending will pause the game, so we need to unpause it
	get_tree().paused = false

func _on_continue_pressed() -> void:
	pass # Replace with function body.


func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(BOONS_SELECTION_SCENE)


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	get_tree().quit()
