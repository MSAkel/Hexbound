extends Control

## Run this scene with F6 to test the segment passives page.
## Every passive is unlocked with extra copies. Nothing writes to the player profile.


func _enter_tree() -> void:
	MetaProgressionManager.begin_ui_sandbox()
	var character := PlayerCharacter.get_default_character()
	GameManager.segment_passives_editor_character = character
	GameManager.selected_character = character


func _exit_tree() -> void:
	MetaProgressionManager.end_ui_sandbox()
