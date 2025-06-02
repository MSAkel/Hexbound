extends CardState

func enter() -> void:
	card_ui.drop_point_area.monitoring = true

func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self, CardState.State.DRAGGING)
		Events.card_drag_started.emit(card_ui)
