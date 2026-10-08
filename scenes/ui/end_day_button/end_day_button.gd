extends Button

## Top-center button that closes the day early once the day target is met.
## Hidden while an hour resolves and during round transitions.

const TOOLTIP_END_DAY := "End the day now. Unused hours pay early-finish gold."


func _ready() -> void:
	hide()
	pressed.connect(_on_pressed)
	mouse_entered.connect(_show_tooltip)
	mouse_exited.connect(_hide_tooltip)

	EventBus.turn_ended.connect(_refresh)
	# turn_started and turn_changed fire before finish_turn_processing clears is_processing_turn.
	EventBus.turn_started.connect(_queue_refresh)
	EventBus.turn_changed.connect(_queue_refresh)
	EventBus.round_changed.connect(_queue_refresh)
	EventBus.total_round_score_changed.connect(_refresh)
	EventBus.required_score_changed.connect(_refresh)
	UiManager.show_round_complete_panel.connect(_refresh)
	_queue_refresh()


func _queue_refresh(_unused = null) -> void:
	call_deferred("_refresh")


func _refresh() -> void:
	var should_show := GameManager.can_end_day_early()
	if visible and not should_show:
		_hide_tooltip()
	visible = should_show


func _on_pressed() -> void:
	# A hand that is about to auto-end the hour is already committed to resolving it.
	var hand := get_tree().get_first_node_in_group("run_hand") as Hand
	if hand != null and hand.has_pending_auto_end():
		return
	_hide_tooltip()
	hide()
	GameManager.end_day_early()


func _show_tooltip() -> void:
	EventBus.toggle_tooltip.emit(true, TOOLTIP_END_DAY, get_global_rect())


func _hide_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())
