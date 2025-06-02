extends CardState

var placed: bool

func enter() -> void:
	Events.card_drag_ended.emit()
	placed = false
	if not card_ui.targets.is_empty():
		placed = true

func on_input(_event: InputEvent) -> void:
	if placed:
		return
	# transition back to base state if not released on a card slot area
	transition_requested.emit(self, CardState.State.BASE)

func on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)
