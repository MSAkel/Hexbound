extends Control

@onready var run_stats_panel: PanelContainer = $RunStatsPanel
@onready var played_as_label: Label = $RunStatsPanel/VBoxContainer/PlayedAsLabel
@onready var layout_xp_bar: LayoutXpBar = %LayoutXpBar
@onready var highest_score_value: Label = $RunStatsPanel/VBoxContainer/HighestScoreValue
@onready var round_value: Label = $RunStatsPanel/VBoxContainer/RoundValue
@onready var gold_earned_value: Label = $RunStatsPanel/VBoxContainer/GoldEarnedValue
@onready var card_triggers_value: Label = $RunStatsPanel/VBoxContainer/CardTriggersValue
@onready var seed_value: Label = $RunStatsPanel/VBoxContainer/SeedContainer/SeedValue

const ENTRANCE_DURATION := 0.5

var _entrance_tween: Tween


func _ready() -> void:
	hide()
	EventBus.all_events_completed.connect(_on_all_events_completed)


func _on_all_events_completed() -> void:
	played_as_label.text = GameManager.selected_character.display_name if GameManager.selected_character else "Unknown"
	highest_score_value.text = CountingNumber.format_int(GameManager.highest_round_score)
	round_value.text = str(GameManager.current_round)
	gold_earned_value.text = CountingNumber.format_int(GoldManager.total_earned_this_run)
	card_triggers_value.text = CountingNumber.format_int(GameManager.total_rune_activations)
	seed_value.text = RunRng.get_display_seed()
	UiManager.show_panel(self)
	_play_entrance_animation()
	# Victory XP is committed when leaving to the menu. Preview the grant here.
	var from_xp := 0
	if GameManager.selected_character != null:
		from_xp = MetaProgressionManager.get_layout_xp(GameManager.selected_character.id)
	var xp_gain := MetaProgressionManager.get_layout_xp_gain_from_snapshot(
		GameManager.build_run_snapshot(true)
	)
	layout_xp_bar.play_gain(from_xp, xp_gain, 0.65)


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
	if not RunRng.copy_display_seed_to_clipboard():
		return
	AudioManager.play_sfx(UISounds.CLICK)


func _on_continue_pressed() -> void:
	hide()
	AudioManager.play_sfx(UISounds.CLICK)
	RoundFlow.notify_victory_continue()


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	MetaProgressionManager.record_run_snapshot(GameManager.build_run_snapshot(true), true)
	RunSaveManager.save_current_run()
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
