extends Control

@onready var run_stats_panel: PanelContainer = $RunStatsPanel
@onready var played_as_label: Label = $RunStatsPanel/VBoxContainer/PlayedAsLabel
@onready var highest_score_value: Label = $RunStatsPanel/VBoxContainer/HighestScoreValue
@onready var round_value: Label = $RunStatsPanel/VBoxContainer/RoundValue
@onready var gold_earned_value: Label = $RunStatsPanel/VBoxContainer/GoldEarnedValue
@onready var card_triggers_value: Label = $RunStatsPanel/VBoxContainer/CardTriggersValue
@onready var seed_value: Label = $RunStatsPanel/VBoxContainer/SeedContainer/SeedValue

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
const ENTRANCE_DURATION := 0.5

var _entrance_tween: Tween


func _ready() -> void:
	hide()
	EventBus.all_challenges_completed.connect(_on_all_challenges_completed)


func _on_all_challenges_completed() -> void:
	played_as_label.text = GameManager.selected_character.display_name if GameManager.selected_character else "Unknown"
	highest_score_value.text = CountingNumber.format_int(GameManager.highest_round_score)
	round_value.text = str(GameManager.current_round)
	gold_earned_value.text = CountingNumber.format_int(GoldManager.total_earned_this_run)
	card_triggers_value.text = CountingNumber.format_int(GameManager.total_rune_activations)
	UiManager.show_panel(self)
	_play_entrance_animation()


func _play_entrance_animation() -> void:
	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()

	# Wait for the centered container to receive its final size before scaling it.
	await get_tree().process_frame
	run_stats_panel.pivot_offset = run_stats_panel.size * 0.5
	var resting_position := run_stats_panel.position
	run_stats_panel.position = resting_position + Vector2(0.0, 36.0)
	run_stats_panel.scale = Vector2(0.82, 0.82)
	run_stats_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(run_stats_panel, "position", resting_position, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(run_stats_panel, "scale", Vector2.ONE, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(run_stats_panel, "modulate", Color.WHITE, ENTRANCE_DURATION * 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_copy_seed_button_pressed() -> void:
	DisplayServer.clipboard_set(seed_value.text)
	AudioManager.play_sfx(UI_SOUNDS.CLICK)


func _on_continue_pressed() -> void:
	hide()
	if UiManager.active_panel == self:
		UiManager.active_panel = null
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	RoundFlow.notify_victory_continue()


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	MetaProgressionManager.record_run_snapshot(GameManager.build_run_snapshot(true), true)
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
