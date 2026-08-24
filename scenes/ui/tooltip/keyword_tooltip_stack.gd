extends VBoxContainer

## One panel per glossary keyword found in a hovered card description.

const TOOLTIP_SCENE := preload("res://scenes/ui/tooltip/tooltip.tscn")
const STACK_GAP := 8
const EDGE_OFFSET := Vector2(10, 10)

var _source: Object = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 101
	add_theme_constant_override("separation", STACK_GAP)
	EventBus.toggle_keyword_tooltips.connect(_on_toggle_keyword_tooltips)
	hide()


func _on_toggle_keyword_tooltips(
	is_visible: bool,
	entries: Array,
	element_rect: Rect2,
	source: Object
) -> void:
	var has_entries := is_visible and not entries.is_empty()
	if has_entries:
		_source = source
		_rebuild_entries(entries)
		# Wait for child min sizes before placing, so the stack does not flash at (0, 0).
		call_deferred("_reposition", element_rect)
		return

	# Empty hover (e.g. Gold only) still claims the slot so the previous card's tips close.
	if is_visible:
		_source = source
		_clear_entries()
		hide()
		return

	# Ignore hide from a card that is no longer the active hover source.
	if source != null and _source != null and source != _source:
		return
	_source = null
	_clear_entries()
	hide()


func _rebuild_entries(entries: Array) -> void:
	_clear_entries()
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var text := String(entry.get("text", ""))
		if text.is_empty():
			continue
		var tooltip := TOOLTIP_SCENE.instantiate() as Tooltip
		tooltip.bind_event_bus = false
		add_child(tooltip)
		tooltip.layout_mode = 2
		tooltip.configure_as_embedded(text)


func _clear_entries() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _reposition(target_rect: Rect2) -> void:
	await get_tree().process_frame
	if _source == null or get_child_count() == 0:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var stack_size := get_combined_minimum_size()
	if stack_size == Vector2.ZERO:
		stack_size = size

	# Pin the stack to the card's top-right corner, then top-left if it would leave the screen.
	var stack_pos := Vector2(target_rect.end.x + EDGE_OFFSET.x, target_rect.position.y)
	if stack_pos.x + stack_size.x > viewport_size.x:
		stack_pos.x = target_rect.position.x - stack_size.x - EDGE_OFFSET.x
	if stack_pos.x < 0.0:
		stack_pos.x = clampf(
			target_rect.position.x,
			0.0,
			maxf(0.0, viewport_size.x - stack_size.x)
		)
		stack_pos.y = target_rect.position.y - stack_size.y - EDGE_OFFSET.y

	if stack_pos.y + stack_size.y > viewport_size.y:
		stack_pos.y = viewport_size.y - stack_size.y
	if stack_pos.y < 0.0:
		stack_pos.y = 0.0
	if stack_pos.x < 0.0:
		stack_pos.x = 0.0
	if stack_pos.x + stack_size.x > viewport_size.x:
		stack_pos.x = viewport_size.x - stack_size.x

	position = stack_pos
	show()
