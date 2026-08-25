extends Control

@onready var played_as_label: Label = $RunStatsPanel/VBoxContainer/PlayedAsLabel
@onready var highest_score_value: Label = $RunStatsPanel/VBoxContainer/HighestScoreValue
@onready var round_value: Label = $RunStatsPanel/VBoxContainer/RoundValue
@onready var gold_earned_value: Label = $RunStatsPanel/VBoxContainer/GoldEarnedValue
@onready var cards_played_value: Label = $RunStatsPanel/VBoxContainer/CardsPlayedValue
@onready var rune_triggers_value: Label = $RunStatsPanel/VBoxContainer/RuneTriggersValue
@onready var seed_value: Label = $RunStatsPanel/VBoxContainer/SeedContainer/SeedValue

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	hide()
	EventBus.game_ended.connect(_on_game_ended)
	played_as_label.text = GameManager.selected_character.display_name if GameManager.selected_character else "Unknown"


func _on_game_ended() -> void:
	RunSaveManager.delete_save()
	UiManager.show_panel(self)
	AudioManager.play_sfx(UI_SOUNDS.GAME_OVER)


func _on_copy_seed_button_pressed() -> void:
	pass # Replace with function body.


func _on_main_menu_button_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")


func _on_new_run_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	RunSaveManager.request_scene_enter_transition()
	get_tree().change_scene_to_file("res://scenes/ui/character_selection_screen/character_selection_screen.tscn")
