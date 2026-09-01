class_name CardBaseState
extends CardState

var mouse_over_card := false
var _enter_generation := 0
var _press_held := false
var _press_screen_pos := Vector2.ZERO

const DRAG_START_THRESHOLD_PX := 8.0


func enter() -> void:
	if not card_ui.is_node_ready():
		await card_ui.ready

	# Clicked state turns this on for drop targeting. Turn it off when idle again.
	card_ui.drop_point_area.monitoring = false
	card_ui.pivot_offset = Vector2.ZERO
	_press_held = false
	_enter_generation += 1
	var generation := _enter_generation
	
	await get_tree().process_frame
	if generation != _enter_generation:
		return
	
	_refresh_hover_state()


func exit(next_state: State = State.BASE) -> void:
	_enter_generation += 1
	_press_held = false
	
	# Keep elevation when selecting so the card does not dip and rise again.
	if next_state != State.CLICKED and card_ui.is_hover_elevated():
		card_ui.set_hover_elevated(false, false)
	
	if next_state != State.CLICKED:
		mouse_over_card = false


func on_gui_input(event: InputEvent) -> void:
	if not mouse_over_card:
		return
	if event.is_action_pressed("left_mouse"):
		# Remember the press. A click with no drag must not start placement.
		_press_held = true
		_press_screen_pos = card_ui.get_global_mouse_position()
		card_ui.get_viewport().set_input_as_handled()


func on_input(event: InputEvent) -> void:
	if not _press_held:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_press_held = false
		# Nudge is click feedback only. Dragging into placement must not shake the card.
		if card_ui.get_global_mouse_position().distance_to(_press_screen_pos) < DRAG_START_THRESHOLD_PX:
			card_ui.play_click_nudge()
		return
	if event is InputEventMouseMotion:
		if card_ui.get_global_mouse_position().distance_to(_press_screen_pos) < DRAG_START_THRESHOLD_PX:
			return
		_press_held = false
		card_ui.get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.CLICKED)


func on_mouse_entered() -> void:
	if card_ui.card_state_machine.current_state != self:
		return
	mouse_over_card = true
	if not card_ui.is_hover_elevated():
		card_ui.set_hover_elevated(true)


func on_mouse_exited() -> void:
	if card_ui.card_state_machine.current_state != self:
		return
	mouse_over_card = false
	if card_ui.is_hover_elevated():
		card_ui.set_hover_elevated(false)


func _refresh_hover_state() -> void:
	# Don't zero offset_transform during intro slides, a hidden hand, or generated-card reveals.
	var hand := card_ui.get_parent() as Hand
	if hand != null and hand.is_preserving_offset_for(card_ui):
		return

	mouse_over_card = card_ui.is_mouse_over()
	if mouse_over_card:
		card_ui.set_hover_elevated(true, not card_ui.is_hover_elevated())
	else:
		card_ui.set_hover_elevated(false, false)
