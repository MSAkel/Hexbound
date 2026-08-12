class_name Tooltip
extends PanelContainer

@onready var label: Label = $Label

const offset: Vector2 = Vector2(10, 10)

var target_rect: Rect2 = Rect2()

func _ready() -> void:
	EventBus.toggle_tooltip.connect(_on_toggle_tooltip)
	hide()
	# Make sure tooltip is on top
	z_index = 100


func _on_toggle_tooltip(is_tooltip_visible: bool, text: String, element_rect: Rect2 = Rect2()) -> void:
	if is_tooltip_visible and text != "":
		target_rect = element_rect
		_update_content(text)
		show()
	else:
		hide()


func _update_content(text: String) -> void:
	label.text = text
	call_deferred("_update_size")


func _update_size() -> void:
	# Let the label reflow with its min width before measuring.
	await get_tree().process_frame
	var label_size := label.get_minimum_size()
	var style := get_theme_stylebox("panel")
	var padding := Vector2(24, 16)
	if style != null:
		padding = Vector2(
			style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT),
			style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
		)
	size = label_size + padding
	_update_position()


func _update_position() -> void:
	if target_rect == Rect2():
		# Fallback to mouse position if no element rect provided
		var mouse_pos = get_viewport().get_mouse_position()
		position = mouse_pos + offset
		_clamp_to_viewport()
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_pos: Vector2
	
	# Try to position tooltip below the element first (default)
	tooltip_pos = Vector2(target_rect.position.x, target_rect.end.y + offset.y)
	
	# If tooltip would go off-screen at bottom, position it above
	if tooltip_pos.y + size.y > viewport_size.y:
		tooltip_pos.y = target_rect.position.y - size.y - offset.y
		
		# If tooltip would go off-screen at top, position it to the right
		if tooltip_pos.y < 0:
			tooltip_pos.y = target_rect.position.y
			tooltip_pos.x = target_rect.end.x + offset.x
			
			# If tooltip would go off-screen to the right, position it to the left
			if tooltip_pos.x + size.x > viewport_size.x:
				tooltip_pos.x = target_rect.position.x - size.x - offset.x
	
	# Ensure tooltip doesn't go off-screen on the left or top
	if tooltip_pos.x < 0:
		tooltip_pos.x = 0
	if tooltip_pos.y < 0:
		tooltip_pos.y = 0
	
	position = tooltip_pos
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Clamp to viewport bounds
	if position.x + size.x > viewport_size.x:
		position.x = viewport_size.x - size.x
	if position.y + size.y > viewport_size.y:
		position.y = viewport_size.y - size.y
	if position.x < 0:
		position.x = 0
	if position.y < 0:
		position.y = 0
