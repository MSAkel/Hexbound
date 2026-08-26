extends Control

## Run this scene directly (F6) to preview end-of-run and shop UI without playing a full run.
## Each button seeds plausible autoload state, then opens the target panel the same way
## the live game does via UiManager or EventBus.

@onready var _trigger_panel: PanelContainer = $TriggerPanel


func _ready() -> void:
	_bootstrap_run_state()
	_build_trigger_buttons()


func _bootstrap_run_state() -> void:
	GameManager.reset_for_new_run()
	GoldManager.set_run_starting_gold(GameManager.selected_difficulty)
	ChallengeManager.init_run()

	# Fake mid-run stats so victory and game-over labels show meaningful values.
	GameManager.apply_run_state({
		"current_round": 7,
		"highest_round_score": 4200,
		"total_round_score": 1850,
		"total_rune_activations": 42,
		"remaining_turns": 2,
	})

	GoldManager.apply_run_state({
		"amount": 120,
		"total_earned_this_run": 340,
		"earned_this_turn": 18,
		"merchant_tokens": 3,
	})


func _build_trigger_buttons() -> void:
	var button_box := _trigger_panel.get_node("MarginContainer/VBoxContainer") as VBoxContainer

	for child in button_box.get_children():
		if child is Button:
			child.queue_free()

	_add_trigger_button(button_box, "Victory screen", _show_victory)
	_add_trigger_button(button_box, "Game over screen", _show_game_over)
	_add_trigger_button(button_box, "Merchant", _show_merchant)
	_add_trigger_button(button_box, "Round complete", _show_round_complete)
	_add_trigger_button(button_box, "Rune selection", _show_rune_selection)
	_add_trigger_button(button_box, "Hide active panel", _hide_active_panel)


func _add_trigger_button(parent: VBoxContainer, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	parent.add_child(button)


func _hide_active_panel() -> void:
	if UiManager.active_panel != null:
		UiManager.active_panel.hide()
		UiManager.active_panel = null


func _show_victory() -> void:
	_hide_active_panel()
	EventBus.all_challenges_completed.emit()


func _show_game_over() -> void:
	_hide_active_panel()
	EventBus.game_ended.emit()


func _show_merchant() -> void:
	_hide_active_panel()
	UiManager.show_merchant_panel.emit()


func _show_round_complete() -> void:
	_hide_active_panel()
	GoldManager.apply_round_speed_rewards(2)
	GameManager.total_round_score = 1850
	UiManager.show_round_complete_panel.emit()


func _show_rune_selection() -> void:
	_hide_active_panel()
	UiManager.show_runes_choice_panel.emit()
