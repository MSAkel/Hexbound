class_name SegmentPassiveListItem
extends PanelContainer

## One row in the passive list. Unlocked rows are clickable, locked rows show progress.

signal passive_pressed(passive_id: String)

const LOCKED_ICON := preload("res://assets/passives/icons/locked_modifier.png")
const TILE_PIP := preload("res://assets/passives/passives_tile.png")
const UNLOCKED_PANEL := preload("res://assets/passives/panels/unlocked_modifier_panel.png")
const LOCKED_PANEL := preload("res://assets/passives/panels/locked_modifier_panel.png")

const COLOR_TITLE := Color(0.18, 0.24, 0.17, 1.0)
const COLOR_BODY := Color(0.39, 0.31, 0.2, 1.0)
const COLOR_MUTED := Color(0.45, 0.4, 0.32, 1.0)
const HEX_SIZE := Vector2(56.0, 65.0)
const ICON_INSET := Vector2(10.0, 12.0)
const PIP_SIZE := Vector2(16.0, 18.0)

var passive_id: String = ""
var _is_unlocked: bool = false
var _is_selectable: bool = false
var _remaining_copies: int = 0
var _icon_texture: Texture2D = null
var _press_position := Vector2.ZERO
var _started_drag: bool = false


func setup(
	passive: SegmentPassive,
	unlocked: bool,
	progress_value: int,
	selectable: bool,
	remaining_copies: int = 0
) -> void:
	passive_id = passive.id
	_is_unlocked = unlocked
	_remaining_copies = remaining_copies
	_is_selectable = unlocked and selectable
	_icon_texture = passive.icon
	_started_drag = false

	for child in get_children():
		child.queue_free()

	add_theme_stylebox_override("panel", _build_panel_style(unlocked))
	# self_modulate tints only the panel art. Children stay at full brightness.
	self_modulate = (
		Color(0.9, 0.9, 0.9, 1.0) if unlocked and remaining_copies <= 0 else Color.WHITE
	)
	mouse_filter = Control.MOUSE_FILTER_STOP if unlocked else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if unlocked and remaining_copies > 0 else Control.CURSOR_ARROW
	)
	tooltip_text = ""

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	row.add_child(_build_hex_icon(passive, unlocked, remaining_copies))
	row.add_child(_build_copy_column(passive, unlocked, progress_value))
	if unlocked:
		row.add_child(_build_cost_column(passive))


func _gui_input(event: InputEvent) -> void:
	if not _is_unlocked or not _is_selectable or _remaining_copies <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
			_started_drag = false
			return
		# Click-to-place only when the pointer did not leave for a drag.
		if _started_drag:
			return
		if event.position.distance_to(_press_position) > 8.0:
			return
		passive_pressed.emit(passive_id)


## Drag carries only the passive icon. Drop targets live on the hex map.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _is_unlocked or _remaining_copies <= 0 or _icon_texture == null:
		return null
	_started_drag = true
	var preview := TextureRect.new()
	preview.texture = _icon_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(72.0, 72.0)
	preview.size = Vector2(72.0, 72.0)
	preview.modulate.a = 0.92
	# Offset so the icon sits on the cursor instead of hanging from its top-left.
	preview.position = Vector2(-36.0, -36.0)
	var preview_root := Control.new()
	preview_root.add_child(preview)
	set_drag_preview(preview_root)
	return {
		"kind": "segment_passive",
		"passive_id": passive_id,
	}


func _build_panel_style(unlocked: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = UNLOCKED_PANEL if unlocked else LOCKED_PANEL
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


## Hex tile with the passive icon inset, matching the loadout map tiles.
func _build_hex_icon(passive: SegmentPassive, unlocked: bool, remaining_copies: int) -> Control:
	var hex := TextureRect.new()
	hex.custom_minimum_size = HEX_SIZE
	hex.texture = TILE_PIP
	hex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hex.clip_contents = false
	if not unlocked:
		hex.modulate = Color(0.7, 0.7, 0.72, 1.0)

	var icon := TextureRect.new()
	icon.texture = passive.icon if unlocked else LOCKED_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = ICON_INSET.x
	icon.offset_top = ICON_INSET.y
	icon.offset_right = -ICON_INSET.x
	icon.offset_bottom = -ICON_INSET.y
	hex.add_child(icon)
	# Show remaining stock when this passive can be placed more than once.
	if unlocked and MetaProgressionManager.get_max_copies(passive) > 1:
		hex.add_child(_build_copies_badge(remaining_copies))
	return hex


func _build_copies_badge(remaining: int) -> Control:
	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(24.0, 24.0)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -20.0
	badge.offset_top = -4.0
	badge.offset_right = 6.0
	badge.offset_bottom = 22.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.22, 0.25, 0.96)
	style.border_color = Color(0.96, 0.84, 0.62, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "x%d" % remaining
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(label)
	return badge


func _build_copy_column(
	passive: SegmentPassive,
	unlocked: bool,
	progress_value: int
) -> VBoxContainer:
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 3)

	if unlocked:
		copy.add_child(_make_label(passive.display_name, 19, COLOR_TITLE))
		copy.add_child(_make_label(passive.description, 14, COLOR_BODY, true))
		return copy

	copy.add_child(_make_label(_requirement_text(passive), 15, COLOR_MUTED, true))
	if passive.unlock_condition != null:
		var ratio := passive.unlock_condition.get_progress_ratio(progress_value)
		if ratio > 0.0:
			copy.add_child(_make_progress_bar(ratio))
		var progress_text := passive.unlock_condition.get_progress_label(progress_value)
		if not progress_text.is_empty():
			copy.add_child(_make_label(progress_text, 13, COLOR_MUTED))
	return copy


## Tile pips mirror how many segment slots this passive will occupy.
func _build_cost_column(passive: SegmentPassive) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 4)

	var tile_count := maxi(1, passive.tile_cost)
	var count_label := _make_label(
		"%d TILE%s" % [tile_count, "" if tile_count == 1 else "S"],
		12,
		COLOR_MUTED
	)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(count_label)

	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_END
	pips.add_theme_constant_override("separation", 3)
	for _pip in tile_count:
		var pip := TextureRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.texture = TILE_PIP
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pips.add_child(pip)
	column.add_child(pips)
	return column


func _make_label(
	text: String,
	font_size: int,
	color: Color,
	wrap: bool = false
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_progress_bar(ratio: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = ratio

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.35, 0.31, 0.24, 0.35)
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.36, 0.45, 0.3, 0.95)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _requirement_text(passive: SegmentPassive) -> String:
	if passive.unlock_condition == null:
		return "Locked"
	if passive.unlock_condition.description.is_empty():
		return "Locked"
	return passive.unlock_condition.description
