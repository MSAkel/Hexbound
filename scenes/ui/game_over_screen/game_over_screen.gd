extends Control

@onready var played_as_label: Label = $RunStatsPanel/VBoxContainer/PlayedAsLabel
@onready var highest_score_value: Label = $RunStatsPanel/VBoxContainer/HighestScoreValue
@onready var round_value: Label = $RunStatsPanel/VBoxContainer/RoundValue
@onready var gold_earned_value: Label = $RunStatsPanel/VBoxContainer/GoldEarnedValue
@onready var card_triggers_value: Label = $RunStatsPanel/VBoxContainer/CardTriggersValue
@onready var seed_value: Label = $RunStatsPanel/VBoxContainer/SeedContainer/SeedValue


func _ready() -> void:
	add_to_group("run_game_over")
	hide()
	EventBus.game_ended.connect(_on_game_ended)


func _on_game_ended() -> void:
	RunSaveManager.delete_save()
	MetaProgressionManager.record_run_snapshot(GameManager.build_run_snapshot(false), true)
	played_as_label.text = GameManager.selected_character.display_name if GameManager.selected_character else "Unknown"
	highest_score_value.text = CountingNumber.format_int(GameManager.highest_round_score)
	round_value.text = str(GameManager.current_round)
	gold_earned_value.text = CountingNumber.format_int(GoldManager.total_earned_this_run)
	card_triggers_value.text = CountingNumber.format_int(GameManager.total_rune_activations)
	seed_value.text = RunRng.get_display_seed()
	UiManager.show_panel(self)
	AudioManager.play_sfx(UISounds.GAME_OVER)


func _on_copy_seed_button_pressed() -> void:
	if not RunRng.copy_display_seed_to_clipboard():
		return
	AudioManager.play_sfx(UISounds.CLICK)


func _on_main_menu_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _on_new_run_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	RunSaveManager.request_scene_enter_transition()
	get_tree().change_scene_to_file(ScenePaths.CHARACTER_SELECTION)
