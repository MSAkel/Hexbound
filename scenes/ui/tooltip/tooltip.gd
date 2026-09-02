class_name Tooltip
extends PanelContainer

@onready var rich_text_label: RichTextLabel = $RichTextLabel

const offset: Vector2 = Vector2(10, 10)

const BODY_COLOR := Color(0.21230483, 0.21230483, 0.21230483, 1)
const HEADER_COLOR := Color(0.36923152, 0.31425732, 0.21094128, 1)
const BODY_FONT_SIZE := 14
const HEADER_FONT_SIZE := 17

# Card keyword panels reuse this scene without listening to the global tooltip bus.
@export var bind_event_bus: bool = true

var target_rect: Rect2 = Rect2()


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
	if rich_text_label != null:
		rich_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_rich_text(text)
	show()


func _on_toggle_tooltip(
	is_tooltip_visible: bool,
	text: String,
	element_rect: Rect2 = Rect2()
) -> void:
	if is_tooltip_visible and text != "":
		target_rect = element_rect
		_update_content(text)
		show()
	else:
		hide()


func _update_content(text: String) -> void:
	_set_rich_text(text)
	call_deferred("_update_size")


func _set_rich_text(text: String) -> void:
	rich_text_label.text = format_tooltip_bbcode(text)


## First line is the tooltip header. Remaining lines are body copy.
static func format_tooltip_bbcode(plain: String) -> String:
	if plain.is_empty():
		return ""

	var newline_index := plain.find("\n")
	if newline_index == -1:
		return _body_bbcode(plain)

	var title := plain.substr(0, newline_index)
	var body := plain.substr(newline_index + 1)
	if body.is_empty():
		return _header_bbcode(title)
	return "%s\n%s" % [_header_bbcode(title), _body_bbcode(body)]


static func _header_bbcode(text: String) -> String:
	return "[font_size=%d][color=#%s]%s[/color][/font_size]" % [
		HEADER_FONT_SIZE,
		HEADER_COLOR.to_html(false),
		_escape_bbcode(text),
	]


static func _body_bbcode(text: String) -> String:
	return "[font_size=%d][color=#%s]%s[/color][/font_size]" % [
		BODY_FONT_SIZE,
		BODY_COLOR.to_html(false),
		_escape_bbcode(text),
	]


static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


func _update_size() -> void:
	# Let the label reflow with its min width before measuring.
	await get_tree().process_frame
	var label_size := rich_text_label.get_minimum_size()
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
