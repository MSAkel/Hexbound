extends CardState

var linked: bool

func enter() -> void:
	#card_ui.color.color = Color.HOT_PINK
	#card_ui.state.text = "LINKED"
	
	linked = false
	
	if not card_ui.targets.is_empty():
		linked = true

func on_input(event: InputEvent) -> void:
	if linked:
		return
		# transition back to base state if not released on a card slot area
	transition_requested.emit(self, CardState.State.BASE)

func on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)
