extends CardState

const DRAG_MINIMUM_THRESHOLD = 0.05
var minimum_drag_time_elapsed := false

# card dragging shouldn't have any change in state, there should be:
# 1- Restricted zone
# 2- Reparenting on releasing inside a card slot zone
func enter() -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		# in my case I would reparent to the card slots instead on drop
		#card_ui.reparent(ui_layer)
		
		card_ui.panel.set("theme_override_styles/panel", card_ui.DRAG_STYLEBOX)
		#card_ui.color.color = Color.BLUE_VIOLET
		#card_ui.state.text = "DRAGGING"
		
		minimum_drag_time_elapsed = false
		var threshold_timer := get_tree().create_timer(DRAG_MINIMUM_THRESHOLD, false)
		threshold_timer.timeout.connect(func(): minimum_drag_time_elapsed = true)

func on_input(event: InputEvent) -> void:
	var mouse_motion := event is InputEventMouseMotion
	# cancel event flag
	var cancel = event.is_action_pressed("right_mouse")
	# cofirm event flag
	var confirm = event.is_action_released("left_mouse") or event.is_action_pressed("left_mouse")
	
	if mouse_motion:
		# Card follow the mouse cursor
		card_ui.global_position = card_ui.get_global_mouse_position() - card_ui.pivot_offset
		
	if cancel:
		transition_requested.emit(self, CardState.State.BASE)
	elif minimum_drag_time_elapsed and confirm:
		get_viewport().set_input_as_handled() # Set input as handled to prevent accidental card drag
		transition_requested.emit(self, CardState.State.LINKED)
