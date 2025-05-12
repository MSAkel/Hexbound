extends CardState

func enter() -> void:
	#card_ui.color.color = Color.ORANGE
	#card_ui.state.text = "CLICKED"
	card_ui.drop_point_area.monitoring = true

func on_input(event: InputEvent) -> void:
	#print(event is InputEventMouseMotion)
	if event is InputEventMouseMotion:
		transition_requested.emit(self, CardState.State.DRAGGING)
