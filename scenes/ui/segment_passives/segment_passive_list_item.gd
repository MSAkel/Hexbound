class_name SegmentPassiveListItem
extends PanelContainer

## One row in the passive list. Unlocked rows are clickable, locked rows show progress.
## Layout lives in segment_passive_list_item.tscn. setup() only fills those nodes.

signal passive_pressed(passive_id: String)

const LOCKED_ICON := preload("res://assets/passives/icons/locked_modifier.png")

@export var unlocked_panel_style: StyleBoxTexture
@export var locked_panel_style: StyleBoxTexture

@onready var _hex_icon: TextureRect = %HexIcon
@onready var _icon: TextureRect = %Icon
@onready var _copies_badge: Panel = %CopiesBadge
@onready var _copies_badge_label: Label = %CopiesBadgeLabel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _requirement_label: Label = %RequirementLabel
@onready var _copies_progress_label: Label = %CopiesProgressLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_detail_label: Label = %ProgressDetailLabel
@onready var _cost_column: VBoxContainer = %CostColumn
@onready var _tile_count_label: Label = %TileCountLabel
@onready var _pips: HBoxContainer = %Pips

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
	_progress_value: int,
	selectable: bool,
	remaining_copies: int = 0
) -> void:
	passive_id = passive.id
	_is_unlocked = unlocked
	_remaining_copies = remaining_copies
	_is_selectable = unlocked and selectable
	_icon_texture = passive.icon
	_started_drag = false

	add_theme_stylebox_override("panel", unlocked_panel_style if unlocked else locked_panel_style)
	# self_modulate tints only the panel art. Children stay at full brightness.
	self_modulate = (
		Color(0.9, 0.9, 0.9, 1.0) if unlocked and remaining_copies <= 0 else Color.WHITE
	)
	mouse_filter = Control.MOUSE_FILTER_STOP if unlocked else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if unlocked and remaining_copies > 0 else Control.CURSOR_ARROW
	)
	tooltip_text = ""

	_hex_icon.modulate = Color.WHITE if unlocked else Color(0.7, 0.7, 0.72, 1.0)
	_icon.texture = passive.icon if unlocked else LOCKED_ICON

	var show_badge := unlocked and MetaProgressionManager.get_max_copies(passive) > 1
	_copies_badge.visible = show_badge
	if show_badge:
		_copies_badge_label.text = "x%d" % remaining_copies

	_title_label.visible = unlocked
	_body_label.visible = unlocked
	_requirement_label.visible = not unlocked
	_cost_column.visible = unlocked
	if unlocked:
		_title_label.text = passive.display_name
		_body_label.text = passive.description
		_fill_unlocked_copy_progress(passive)
		_fill_cost_column(passive)
	else:
		_requirement_label.text = _requirement_text(passive)
		_fill_locked_progress(passive)


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


## Unlocked passives with extra gated copies show 2/3 plus the next threshold.
func _fill_unlocked_copy_progress(passive: SegmentPassive) -> void:
	if maxi(1, passive.max_copies) <= 1:
		_copies_progress_label.visible = false
		_progress_bar.visible = false
		_progress_detail_label.visible = false
		return
	var state := MetaProgressionManager.get_copy_unlock_state(passive)
	var unlocked_copies := int(state.get("unlocked_copies", 1))
	var max_copies := int(state.get("max_copies", 1))
	_copies_progress_label.visible = true
	_copies_progress_label.text = "%d/%d copies" % [unlocked_copies, max_copies]
	if bool(state.get("all_unlocked", true)):
		_progress_bar.visible = false
		_progress_detail_label.visible = false
		return
	var needed := int(state.get("needed", 0))
	if needed <= 0:
		_progress_bar.visible = false
		_progress_detail_label.visible = false
		return
	var progress := int(state.get("progress", 0))
	_progress_bar.visible = true
	_progress_bar.value = clampf(float(progress) / float(needed), 0.0, 1.0)
	_progress_detail_label.visible = true
	_progress_detail_label.text = String(state.get("label", ""))


func _fill_locked_progress(passive: SegmentPassive) -> void:
	_copies_progress_label.visible = false
	var display := MetaProgressionManager.get_unlock_progress_display(passive)
	var ratio := float(display.get("ratio", 0.0))
	_progress_bar.visible = ratio > 0.0
	_progress_bar.value = ratio
	var progress_text := String(display.get("label", ""))
	_progress_detail_label.visible = not progress_text.is_empty()
	_progress_detail_label.text = progress_text


## Tile pips mirror how many segment slots this passive will occupy.
func _fill_cost_column(passive: SegmentPassive) -> void:
	var tile_count := maxi(1, passive.tile_cost)
	_tile_count_label.text = "%d TILE%s" % [tile_count, "" if tile_count == 1 else "S"]
	for index in _pips.get_child_count():
		_pips.get_child(index).visible = index < tile_count


func _requirement_text(passive: SegmentPassive) -> String:
	if passive.unlock_condition == null:
		return "Locked"
	if passive.unlock_condition.description.is_empty():
		return "Locked"
	return passive.unlock_condition.description
