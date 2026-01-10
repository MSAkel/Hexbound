extends CardState

var mouse_over_card := false
var base_position: Vector2
var is_elevated := false
var elevation_tween: Tween
const ELEVATION_OFFSET := -40.0
const ANIMATION_DURATION := 0.2

func enter() -> void:
	if not card_ui.is_node_ready():
		await card_ui.ready
	# Move card back to hand if dragged or released in an unplayable zone
	card_ui.reparent_requested.emit(card_ui)
	# pivot offset to prevent card snapping to mouse cursor at (0,0) and on cursor location instead
	card_ui.pivot_offset = Vector2.ZERO
	# Kill any existing tween
	if elevation_tween:
		elevation_tween.kill()
		elevation_tween = null
	# Wait for reparenting to complete and layout to update
	await get_tree().process_frame
	await get_tree().process_frame
	# Store base position and reset elevation after reparenting
	base_position = card_ui.position
	is_elevated = false
	# Reset elevation if it was elevated (with animation)
	if mouse_over_card:
		_animate_elevate()
	else:
		card_ui.position = base_position
	
func exit() -> void:
	# Kill any active tween when leaving BASE state
	if elevation_tween:
		elevation_tween.kill()
		elevation_tween = null
	# Reset elevation when leaving BASE state (instant, no animation on exit)
	if is_elevated:
		card_ui.position = base_position
		is_elevated = false
	mouse_over_card = false
	
func on_gui_input(event: InputEvent) -> void:
	if mouse_over_card and event.is_action_pressed("left_mouse"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self, CardState.State.CLICKED)

func on_mouse_entered() -> void:
	# Only process if we're still in BASE state (prevent elevation during state transitions)
	if card_ui.card_state_machine.current_state != self:
		return
	mouse_over_card = true
	if not is_elevated:
		base_position = card_ui.position
		_animate_elevate()

func on_mouse_exited() -> void:
	# Only process if we're still in BASE state (prevent position changes during state transitions)
	if card_ui.card_state_machine.current_state != self:
		return
	mouse_over_card = false
	if is_elevated:
		_animate_reset()

func _animate_elevate() -> void:
	# Kill any existing tween
	if elevation_tween:
		elevation_tween.kill()
	
	is_elevated = true
	var target_position := base_position + Vector2(0, ELEVATION_OFFSET)
	elevation_tween = create_tween()
	elevation_tween.set_ease(Tween.EASE_OUT)
	elevation_tween.set_trans(Tween.TRANS_QUART)
	elevation_tween.tween_property(card_ui, "position", target_position, ANIMATION_DURATION)
	elevation_tween.tween_callback(func(): 
		elevation_tween = null
	)

func _animate_reset() -> void:
	# Kill any existing tween
	if elevation_tween:
		elevation_tween.kill()
	
	is_elevated = false
	elevation_tween = create_tween()
	elevation_tween.set_ease(Tween.EASE_IN)
	elevation_tween.set_trans(Tween.TRANS_QUART)
	elevation_tween.tween_property(card_ui, "position", base_position, ANIMATION_DURATION)
	elevation_tween.tween_callback(func(): 
		elevation_tween = null
	)
