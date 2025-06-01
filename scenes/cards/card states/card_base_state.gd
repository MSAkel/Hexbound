extends CardState

var mouse_over_card := false

func enter() -> void:
	if not card_ui.is_node_ready():
		await card_ui.ready
	# Move card back to hand if dragged or released in an unplayable zone
	card_ui.reparent_requested.emit(card_ui)
	# pivot offset to prevent card snapping to mouse cursor at (0,0) and on cursor location instead
	card_ui.pivot_offset = Vector2.ZERO
	
func on_gui_input(event: InputEvent) -> void:
	if mouse_over_card and event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)

func on_mouse_entered() -> void:
	mouse_over_card = true
	
func on_mouse_exited() -> void:
	mouse_over_card = false
