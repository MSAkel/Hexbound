class_name Tooltip
extends PanelContainer

enum Placement {
	AUTO,
	## Anchor rect x is the host panel's right edge. Tooltip opens to the right, aligned to the row.
	RIGHT_OF_ANCHOR,
}

@onready var label: Label = $Label

const offset: Vector2 = Vector2(10, 10)

# Card keyword panels reuse this scene without listening to the global tooltip bus.
@export var bind_event_bus: bool = true

var target_rect: Rect2 = Rect2()
var _placement: Placement = Placement.AUTO

func _ready() -> void:
	if bind_event_bus:
		EventBus.toggle_tooltip.connect(_on_toggle_tooltip)
		EventBus.tooltip_hover_refresh_requested.connect(_on_hover_refresh_requested)
	hide()
	# Make sure tooltip is on top
	z_index = 100


func _exit_tree() -> void:
	if not bind_event_bus:
		return
	if EventBus.toggle_tooltip.is_connected(_on_toggle_tooltip):
		EventBus.toggle_tooltip.disconnect(_on_toggle_tooltip)
	if EventBus.tooltip_hover_refresh_requested.is_connected(_on_hover_refresh_requested):
		EventBus.tooltip_hover_refresh_requested.disconnect(_on_hover_refresh_requested)


func _on_hover_refresh_requested() -> void:
	# Let the covering control leave the GUI picking tree before replaying the pointer.
	await get_tree().process_frame
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = get_viewport().get_mouse_position()
	mouse_motion.global_position = mouse_motion.position
	get_viewport().push_input(mouse_motion, true)


# Used when this panel is stacked beside a hovered card description.
func configure_as_embedded(text: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = text
	show()


func _on_toggle_tooltip(
	is_tooltip_visible: bool,
	text: String,
	element_rect: Rect2 = Rect2(),
	placement: int = Placement.AUTO
) -> void:
	if is_tooltip_visible and text != "":
		target_rect = element_rect
		_placement = placement as Placement
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

	if _placement == Placement.RIGHT_OF_ANCHOR:
		_position_right_of_anchor()
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


## Opens beside the host panel with the hovered row centered vertically on the tooltip.
func _position_right_of_anchor() -> void:
	var tooltip_pos := Vector2(target_rect.position.x + offset.x, target_rect.position.y)
	if target_rect.size.y > 0.0:
		tooltip_pos.y += (target_rect.size.y - size.y) * 0.5

	var viewport_size := get_viewport().get_visible_rect().size
	var min_x := target_rect.position.x + offset.x

	if tooltip_pos.y < 0.0:
		tooltip_pos.y = 0.0
	if tooltip_pos.y + size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - size.y

	if tooltip_pos.x + size.x > viewport_size.x:
		tooltip_pos.x = viewport_size.x - size.x
	tooltip_pos.x = maxf(tooltip_pos.x, min_x)

	position = tooltip_pos


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
