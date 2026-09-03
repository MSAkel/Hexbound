class_name LayoutPreviewMap
extends VBoxContainer

## Live hex cluster for layout select. Trigger order and segments come from HexMapLayout.

enum LegendFilter {
	NONE,
	TRIGGER_ORDER,
	SEGMENTS,
	STARTS,
	ENDS,
}

const PREVIEW_MAP_SCENE := preload("res://scenes/ui/segment_passives/segment_passives_preview_map.tscn")
const TILE_NORMAL := preload("res://assets/map/segment_icons/tile_normal.png")
const TILE_SEGMENT_START := preload("res://assets/map/segment_icons/tile_segment_start.png")
const TILE_SEGMENT_END := preload("res://assets/map/segment_icons/tile_segment_end.png")
const TILE_SEGMENT_BOTH := preload("res://assets/map/segment_icons/tile_segment_both.png")

const MAX_CONTENT_SCALE := 1.0
# Extra pixels between neighboring hexes, measured center to center.
const TILE_SPACING_PX := 6.0
# Hitbox grows this far past each hex so the visual gap still counts as that tile.
const TILE_HIT_PADDING_PX := TILE_SPACING_PX
const PLAYBACK_DURATION := 1.7
const TRAIL_LENGTH := 4
const NUMBER_FONT_SIZE := 68
const NUMBER_OUTLINE_SIZE := 14
# Pointy hex art sits a little high. Nudge numbers toward the visual center.
const NUMBER_Y_OFFSET := -8.0

const CAPTION_IDLE := "Hover a spot to inspect a course"
const CAPTION_PLAYING := "Cards fire in this order"
const CAPTION_TRIGGER_ORDER := "Numbers show the order cards fire in"
const CAPTION_SEGMENTS := "Each course consists of one or more spots"
const CAPTION_STARTS := "First spot in each course"
const CAPTION_ENDS := "Last spot in each course"

const TEXT_CAPTION := Color(0.39, 0.31, 0.2, 1)
const NUMBER_COLOR := Color(0.96, 0.94, 0.88, 1)
const NUMBER_OUTLINE := Color(0.10, 0.14, 0.10, 1)
const PLAYBACK_FLASH := Color(0.98, 0.94, 0.62, 1.0)
const DIM_RGB := 0.42
const DIM_ALPHA := 0.55

@onready var _map_host: Control = %MapHost
@onready var _caption_label: Label = %CaptionLabel
@onready var _replay_button: Button = %ReplayButton

var _character: CharacterDefinition = null
var _preview_map: SegmentPassivesPreviewMap = null
var _content: Control = null
var _content_size: Vector2 = Vector2.ZERO
var _tiles: Dictionary = {}
var _labels: Dictionary = {}
var _tile_segments: Dictionary = {}
var _tile_order: Dictionary = {}
var _order_coords: Array[Vector2i] = []
var _segment_count: int = 0

var _legend_filter: LegendFilter = LegendFilter.NONE
var _hover_coords := Vector2i(-999, -999)
var _hover_segment_index: int = -1
var _pinned_segment_index: int = -1

var _playback_tween: Tween = null
var _playback_index: int = -1
var _playback_active: bool = false
var _playback_finished: bool = false


func _ready() -> void:
	_map_host.clip_contents = true
	_map_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.resized.connect(_update_content_transform)
	_replay_button.pressed.connect(_on_replay_pressed)
	_caption_label.add_theme_color_override("font_color", TEXT_CAPTION)


func setup(character: CharacterDefinition) -> void:
	_character = character
	_pinned_segment_index = -1
	_hover_coords = Vector2i(-999, -999)
	_hover_segment_index = -1
	_legend_filter = LegendFilter.NONE
	_rebuild_map()


func set_legend_filter(filter: LegendFilter) -> void:
	if _legend_filter == filter:
		return
	_legend_filter = filter
	if not _is_playing_order():
		if filter != LegendFilter.NONE:
			_pause_playback()
		else:
			_resume_playback_if_idle()
	_refresh_visuals()
	_refresh_caption()


func cleanup() -> void:
	_kill_playback()
	if _preview_map != null:
		_preview_map.restore_character_context()
		_preview_map = null
	_content = null
	_tiles.clear()
	_labels.clear()
	_tile_segments.clear()
	_tile_order.clear()
	_order_coords.clear()
	if _map_host == null:
		return
	for child in _map_host.get_children():
		child.queue_free()


func _exit_tree() -> void:
	cleanup()


func _rebuild_map() -> void:
	_kill_playback()
	if _preview_map != null:
		_preview_map.restore_character_context()
		_preview_map = null
	for child in _map_host.get_children():
		child.queue_free()
	_tiles.clear()
	_labels.clear()
	_tile_segments.clear()
	_tile_order.clear()
	_order_coords.clear()
	_content = null
	_segment_count = 0

	if _character == null:
		return

	# Hidden layout source. Same hex grid as segment passives, with this character's rules.
	_preview_map = PREVIEW_MAP_SCENE.instantiate() as SegmentPassivesPreviewMap
	_preview_map.visible = false
	_preview_map.modulate.a = 0.0
	_map_host.add_child(_preview_map)
	_preview_map.setup_character(_character)
	# Order is computed from the preview map's character. Restore GameManager so browsing does not lock a layout.
	_preview_map.restore_character_context()

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.add_child(_content)

	var tile_size := _preview_map.get_tile_pixel_size()
	var min_pos := Vector2(INF, INF)
	var tile_positions: Dictionary = {}
	var order := 1
	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		var tile_pos := _preview_map.local_position_for_coords(coords)
		tile_positions[coords] = tile_pos
		min_pos = min_pos.min(tile_pos)
		_order_coords.append(coords)
		_tile_order[coords] = order
		_tile_segments[coords] = _preview_map.get_segment_index(coords)
		order += 1

	if not is_finite(min_pos.x):
		return

	var spacing_scale := 1.0
	var neighbor_dist := _min_neighbor_distance(tile_positions)
	if is_finite(neighbor_dist) and neighbor_dist > 0.0:
		spacing_scale = (neighbor_dist + TILE_SPACING_PX) / neighbor_dist

	_segment_count = _preview_map.get_segment_count()
	var hit_padding := Vector2(TILE_HIT_PADDING_PX, TILE_HIT_PADDING_PX)
	var hit_size := tile_size + hit_padding * 2.0
	var layout_max := Vector2.ZERO
	for coords: Vector2i in _order_coords:
		var origin: Vector2 = tile_positions[coords]
		var placed: Vector2 = (origin - min_pos) * spacing_scale
		layout_max = layout_max.max(placed + hit_size)
	_content_size = layout_max
	_content.custom_minimum_size = _content_size
	_content.size = _content_size

	for coords: Vector2i in _order_coords:
		var segment_index: int = int(_tile_segments[coords])
		var is_start := _preview_map.is_first_tile_in_segment(coords)
		var is_end := _preview_map.is_last_tile_in_segment(coords)
		var host := _make_tile_host(tile_size, is_start, is_end)
		var origin: Vector2 = tile_positions[coords]
		host.position = (origin - min_pos) * spacing_scale
		host.gui_input.connect(_on_tile_gui_input.bind(segment_index, coords))
		host.mouse_entered.connect(_on_tile_mouse_entered.bind(segment_index, coords))
		host.mouse_exited.connect(_on_tile_mouse_exited.bind(segment_index, coords))
		_content.add_child(host)

		var tile := host.get_child(0) as TextureRect
		var label := _make_order_label(tile_size, int(_tile_order[coords]))
		tile.add_child(label)

		_tiles[coords] = tile
		_labels[coords] = label

	_update_content_transform()
	call_deferred("_update_content_transform")
	_refresh_visuals()
	_refresh_caption()


func _make_tile_host(tile_size: Vector2, is_start: bool, is_end: bool) -> Control:
	var hit_padding := Vector2(TILE_HIT_PADDING_PX, TILE_HIT_PADDING_PX)
	var host := Control.new()
	host.custom_minimum_size = tile_size + hit_padding * 2.0
	host.size = host.custom_minimum_size
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var tile := TextureRect.new()
	if is_start and is_end:
		tile.texture = TILE_SEGMENT_BOTH
	elif is_start:
		tile.texture = TILE_SEGMENT_START
	elif is_end:
		tile.texture = TILE_SEGMENT_END
	else:
		tile.texture = TILE_NORMAL
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.custom_minimum_size = tile_size
	tile.size = tile_size
	tile.position = hit_padding
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(tile)
	return host


func _make_order_label(tile_size: Vector2, order: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0.0, NUMBER_Y_OFFSET)
	label.size = tile_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = str(order)
	label.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", NUMBER_OUTLINE)
	label.add_theme_constant_override("outline_size", NUMBER_OUTLINE_SIZE)
	return label


func _update_content_transform() -> void:
	if _content == null or _content_size.x <= 0.0 or _content_size.y <= 0.0:
		return
	if _map_host.size.x <= 0.0 or _map_host.size.y <= 0.0:
		return
	var fit_scale := minf(_map_host.size.x / _content_size.x, _map_host.size.y / _content_size.y)
	fit_scale = minf(fit_scale, MAX_CONTENT_SCALE)
	_content.scale = Vector2(fit_scale, fit_scale)
	_content.position = (_map_host.size - _content_size * fit_scale) * 0.5


## Smallest distance between two hex top-lefts. Used to turn a pixel gap into a layout scale.
func _min_neighbor_distance(tile_positions: Dictionary) -> float:
	var min_dist := INF
	var positions: Array = tile_positions.values()
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			var dist: float = (positions[i] as Vector2).distance_to(positions[j] as Vector2)
			if dist > 0.0 and dist < min_dist:
				min_dist = dist
	return min_dist


func _start_playback() -> void:
	_kill_playback()
	if _order_coords.is_empty():
		_playback_finished = true
		_refresh_visuals()
		_refresh_caption()
		return

	_playback_active = true
	_playback_finished = false
	_playback_index = -1
	_refresh_visuals()
	_refresh_caption()

	var step := PLAYBACK_DURATION / float(_order_coords.size())
	_playback_tween = create_tween()
	for index in _order_coords.size():
		_playback_tween.tween_callback(_advance_playback.bind(index))
		_playback_tween.tween_interval(step)
	_playback_tween.tween_callback(_finish_playback)


func _advance_playback(index: int) -> void:
	_playback_index = index
	_refresh_visuals()


func _finish_playback() -> void:
	_playback_active = false
	_playback_finished = true
	_playback_index = _order_coords.size() - 1
	_refresh_visuals()
	_refresh_caption()


func _is_playing_order() -> bool:
	return _playback_active and not _playback_finished


func _pause_playback() -> void:
	if _playback_tween != null and _playback_tween.is_valid() and _playback_tween.is_running():
		_playback_tween.pause()


func _resume_playback_if_idle() -> void:
	if not _playback_active or _playback_finished:
		return
	if _legend_filter != LegendFilter.NONE:
		return
	if _hover_segment_index >= 0 or _pinned_segment_index >= 0:
		return
	if _playback_tween != null and _playback_tween.is_valid():
		_playback_tween.play()


func _kill_playback() -> void:
	if _playback_tween != null and _playback_tween.is_valid():
		_playback_tween.kill()
	_playback_tween = null
	_playback_active = false
	_playback_finished = false
	_playback_index = -1


func _on_replay_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_pinned_segment_index = -1
	_start_playback()


func _on_tile_gui_input(event: InputEvent, segment_index: int, _coords: Vector2i) -> void:
	if _is_playing_order():
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _pinned_segment_index == segment_index:
		_pinned_segment_index = -1
		_resume_playback_if_idle()
	else:
		_pinned_segment_index = segment_index
		_pause_playback()
	_refresh_visuals()
	_refresh_caption()


func _on_tile_mouse_entered(segment_index: int, coords: Vector2i) -> void:
	_hover_segment_index = segment_index
	_hover_coords = coords
	# Order playback owns the dimming until it finishes. Hover is applied after.
	if _is_playing_order():
		return
	_pause_playback()
	_refresh_visuals()
	_refresh_caption()


func _on_tile_mouse_exited(_segment_index: int, coords: Vector2i) -> void:
	# Only clear if this tile still owns the hover. Overlapping hitboxes can exit
	# after the next tile has already entered.
	if _hover_coords == coords:
		_hover_coords = Vector2i(-999, -999)
		_hover_segment_index = -1
	if _is_playing_order():
		return
	call_deferred("_refresh_hover_after_tile_leave")


## Wait a frame so moving into a neighbor hex does not flash the whole map dim.
func _refresh_hover_after_tile_leave() -> void:
	if _is_playing_order():
		return
	_refresh_visuals()
	_refresh_caption()
	_resume_playback_if_idle()


func _refresh_caption() -> void:
	if _caption_label == null:
		return
	if _is_playing_order():
		_caption_label.text = CAPTION_PLAYING
		return
	var hover_in_focus := _hover_coords != Vector2i(-999, -999) and _tiles.has(_hover_coords)
	if hover_in_focus:
		if _pinned_segment_index < 0 or _hover_segment_index == _pinned_segment_index:
			_caption_label.text = _tile_caption(_hover_coords)
			return
	if _pinned_segment_index >= 0:
		_caption_label.text = "%s %d of %d pinned" % [
			FeastDisplay.COURSE,
			_pinned_segment_index + 1,
			_segment_count,
		]
		return
	match _legend_filter:
		LegendFilter.TRIGGER_ORDER:
			_caption_label.text = CAPTION_TRIGGER_ORDER
		LegendFilter.SEGMENTS:
			_caption_label.text = CAPTION_SEGMENTS
		LegendFilter.STARTS:
			_caption_label.text = CAPTION_STARTS
		LegendFilter.ENDS:
			_caption_label.text = CAPTION_ENDS
		_:
			if _playback_active and not _playback_finished:
				_caption_label.text = CAPTION_PLAYING
			else:
				_caption_label.text = CAPTION_IDLE


func _tile_caption(coords: Vector2i) -> String:
	var order: int = int(_tile_order.get(coords, 0))
	var segment_index: int = int(_tile_segments.get(coords, 0))
	var text := "%s %d · %s %d of %d" % [
		FeastDisplay.SPOT,
		order,
		FeastDisplay.COURSE,
		segment_index + 1,
		_segment_count,
	]
	if _preview_map != null and _preview_map.is_first_tile_in_segment(coords):
		text += " · %s start" % FeastDisplay.COURSE
	if _preview_map != null and _preview_map.is_last_tile_in_segment(coords):
		text += " · %s end" % FeastDisplay.COURSE
	return text


func _refresh_visuals() -> void:
	for coords: Vector2i in _tiles.keys():
		_apply_tile_visual(coords)


func _apply_tile_visual(coords: Vector2i) -> void:
	var tile: TextureRect = _tiles[coords]
	var label: Label = _labels[coords]
	var order_index: int = int(_tile_order[coords]) - 1
	var segment_index: int = int(_tile_segments[coords])
	var is_start := _preview_map != null and _preview_map.is_first_tile_in_segment(coords)
	var is_end := _preview_map != null and _preview_map.is_last_tile_in_segment(coords)

	# Icon art carries start, end, and normal color. Modulate only highlight and dim.
	var color := Color.WHITE
	var emphasized := _is_emphasized(coords, segment_index, order_index, is_start, is_end)
	var number_visible := _is_number_visible(order_index)

	if _playback_active and not _playback_finished and _legend_filter == LegendFilter.NONE:
		if order_index == _playback_index:
			color = color.lerp(PLAYBACK_FLASH, 0.72)
		elif _is_in_trail(order_index):
			var trail_t := 1.0 - float(_playback_index - order_index) / float(TRAIL_LENGTH)
			color = color.lerp(PLAYBACK_FLASH, 0.22 * trail_t)

	if not emphasized:
		color = Color(color.r * DIM_RGB, color.g * DIM_RGB, color.b * DIM_RGB, DIM_ALPHA)

	tile.modulate = color
	label.visible = number_visible
	label.modulate = Color(1, 1, 1, 1.0 if emphasized else 0.4)


func _is_emphasized(
	_coords: Vector2i,
	segment_index: int,
	order_index: int,
	is_start: bool,
	is_end: bool
) -> bool:
	if _is_playing_order():
		return order_index <= _playback_index

	match _legend_filter:
		LegendFilter.TRIGGER_ORDER:
			return true
		LegendFilter.SEGMENTS:
			return true
		LegendFilter.STARTS:
			return is_start
		LegendFilter.ENDS:
			return is_end
		_:
			pass

	var focus_segment := _pinned_segment_index if _pinned_segment_index >= 0 else _hover_segment_index
	if focus_segment >= 0:
		return segment_index == focus_segment
	return true


func _is_number_visible(order_index: int) -> bool:
	if _legend_filter != LegendFilter.NONE:
		return true
	if _playback_active and not _playback_finished:
		return order_index <= _playback_index
	return true


func _is_in_trail(order_index: int) -> bool:
	if _playback_index < 0:
		return false
	return order_index < _playback_index and order_index >= _playback_index - TRAIL_LENGTH
