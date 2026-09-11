extends CardState


func enter() -> void:
	card_ui.drop_point_area.monitoring = true
	# Hand hides this card in-place and slides siblings. The cursor ghost is the visual.
	EventBus.card_drag_started.emit(card_ui)


func exit(_next_state: State = State.BASE) -> void:
	card_ui.hide_selection_glow()
	EventBus.card_drag_ended.emit()


func on_gui_input(event: InputEvent) -> void:
	# Placement is drag-to-drop. A second press is not used to cancel.
	if event.is_action_pressed("left_mouse"):
		card_ui.get_viewport().set_input_as_handled()


func on_input(event: InputEvent) -> void:
	if event.is_action_pressed("right_mouse") or event.is_action_pressed("ui_cancel"):
		card_ui.get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.BASE)


func on_mouse_entered() -> void:
	# Placement morph and lift are driven by CardPlacementHandler using the visual card rect.
	pass


func on_mouse_exited() -> void:
	# Layout mouse-exit fires before the cursor leaves the lifted card. Do not snap the morph here.
	pass
