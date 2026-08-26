extends Control

@onready var played_as_label: Label = $RunStatsPanel/VBoxContainer/PlayedAsLabel
@onready var highest_score_value: Label = $RunStatsPanel/VBoxContainer/HighestScoreValue
@onready var round_value: Label = $RunStatsPanel/VBoxContainer/RoundValue
@onready var gold_earned_value: Label = $RunStatsPanel/VBoxContainer/GoldEarnedValue
@onready var card_triggers_value: Label = $RunStatsPanel/VBoxContainer/CardTriggersValue
@onready var seed_value: Label = $RunStatsPanel/VBoxContainer/SeedContainer/SeedValue

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	hide()
	EventBus.game_ended.connect(_on_game_ended)


func _on_game_ended() -> void:
	RunSaveManager.delete_save()
	played_as_label.text = GameManager.selected_character.display_name if GameManager.selected_character else "Unknown"
	highest_score_value.text = CountingNumber.format_int(GameManager.highest_round_score)
	round_value.text = str(GameManager.current_round)
	gold_earned_value.text = CountingNumber.format_int(GoldManager.total_earned_this_run)
	card_triggers_value.text = CountingNumber.format_int(GameManager.total_rune_activations)
	UiManager.show_panel(self)
	AudioManager.play_sfx(UI_SOUNDS.GAME_OVER)


func _on_copy_seed_button_pressed() -> void:
	DisplayServer.clipboard_set(seed_value.text)
	AudioManager.play_sfx(UI_SOUNDS.CLICK)


func _on_main_menu_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")


func _on_new_run_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	RunSaveManager.request_scene_enter_transition()
	get_tree().change_scene_to_file("res://scenes/ui/character_selection_screen/character_selection_screen.tscn")
