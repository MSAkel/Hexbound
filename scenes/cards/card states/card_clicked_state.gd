extends CardState

func enter() -> void:
	card_ui.drop_point_area.monitoring = true

func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self, CardState.State.DRAGGING)
		Events.card_drag_started.emit(card_ui)

func on_mouse_entered() -> void:
	# Ignore mouse entered events while clicked (prevent elevation)
	pass

func on_mouse_exited() -> void:
	# Ignore mouse exited events while clicked (prevent elevation reset)
	pass
