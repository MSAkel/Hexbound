class_name RunHistoryBoardView
extends Control

## Read-only hex preview of a finished run's board.
## Hidden SegmentPassivesPreviewMap supplies layout coords and pixel sizes.
## Visible tiles are Control hosts so CardIcon can sit on each hex.

const PREVIEW_MAP_SCENE := preload("res://scenes/ui/segment_passives/segment_passives_preview_map.tscn")
const CARD_ICON_SCENE := preload("res://scenes/ui/cards/card_icon.tscn")
const TILE_NORMAL := preload("res://assets/map/segment_icons/tile_normal.png")
const TILE_SEGMENT_START := preload("res://assets/map/segment_icons/tile_segment_start.png")
const TILE_SEGMENT_END := preload("res://assets/map/segment_icons/tile_segment_end.png")
const TILE_SEGMENT_BOTH := preload("res://assets/map/segment_icons/tile_segment_both.png")

const MAX_CONTENT_SCALE := 1.0
## Extra pixels between neighboring hex centers after layout.
const TILE_SPACING_PX := 4.0
const DISABLED_MODULATE := Color(0.35, 0.35, 0.38, 0.55)
const EMPTY_MODULATE := Color(0.72, 0.72, 0.7, 0.85)
const NO_HOVER := Vector2i(-999, -999)

@onready var _map_host: Control = %MapHost
@onready var _caption_label: Label = %CaptionLabel

var _character: CharacterDefinition = null
## card_id keyed by hex coords from the archived snapshot.
var _placed_by_coords: Dictionary = {}
var _disabled_coords: Dictionary = {}
var _preview_map: SegmentPassivesPreviewMap = null
## Scaled cluster of tile hosts. Fit into MapHost without stretching hex art.
var _content: Control = null
var _content_size := Vector2.ZERO
var _tiles: Dictionary = {}
var _hover_coords := NO_HOVER


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _map_host == null:
		return
	_map_host.clip_contents = true
	_map_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.resized.connect(_update_content_transform)


## Load a layout and the slim board dict from RunHistoryManager.
## board uses placed[{card_id, coords}] and disabled_coords.
func setup(character_id: String, board: Dictionary) -> void:
	_character = PlayerCharacter.get_character_by_id(character_id)
	_placed_by_coords = _parse_placed_cards(board.get("placed", []))
	_disabled_coords = _parse_disabled_coords(board.get("disabled_coords", []))
	_rebuild_map()


func clear_board() -> void:
	_character = null
	_placed_by_coords.clear()
	_disabled_coords.clear()
	cleanup()
	_set_caption("No board saved for this run")


func cleanup() -> void:
	EventBus.toggle_tooltip.emit(false, "")
	if _preview_map != null:
		_preview_map.restore_character_context()
		_preview_map = null
	_content = null
	_tiles.clear()
	_hover_coords = NO_HOVER
	if _map_host == null:
		return
	for child in _map_host.get_children():
		child.queue_free()


func _exit_tree() -> void:
	cleanup()


func _rebuild_map() -> void:
	cleanup()
	if _character == null or _map_host == null:
		_set_caption("Unknown layout")
		return

	# Hidden layout source. Same hex grid as character select.
	# Restore GameManager after setup so browsing Stats does not lock a layout.
	_preview_map = PREVIEW_MAP_SCENE.instantiate() as SegmentPassivesPreviewMap
	_preview_map.visible = false
	_preview_map.modulate.a = 0.0
	_map_host.add_child(_preview_map)
	_preview_map.setup_character(_character)
	_preview_map.restore_character_context()

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.add_child(_content)

	var tile_size := _preview_map.get_tile_pixel_size()
	var tile_positions := _collect_tile_positions()
	if tile_positions.is_empty():
		return

	var min_pos := _min_position(tile_positions)
	var spacing_scale := _spacing_scale(tile_positions)
	_content_size = _measure_content_size(tile_positions, min_pos, spacing_scale, tile_size)
	_content.custom_minimum_size = _content_size
	_content.size = _content_size

	for coords: Vector2i in tile_positions.keys():
		var host := _make_tile_host(tile_size, coords)
		var origin: Vector2 = tile_positions[coords]
		host.position = (origin - min_pos) * spacing_scale
		_content.add_child(host)
		_tiles[coords] = host

		var card_id := String(_placed_by_coords.get(coords, ""))
		if not card_id.is_empty():
			_place_card_icon(host, tile_size, card_id)
		_apply_occupancy_modulate(host, coords, card_id)

	_update_content_transform()
	call_deferred("_update_content_transform")
	_refresh_caption()


func _collect_tile_positions() -> Dictionary:
	var tile_positions: Dictionary = {}
	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		tile_positions[coords] = _preview_map.local_position_for_coords(coords)
	return tile_positions


func _min_position(tile_positions: Dictionary) -> Vector2:
	var min_pos := Vector2(INF, INF)
	for tile_pos: Vector2 in tile_positions.values():
		min_pos = min_pos.min(tile_pos)
	return min_pos


## Stretch neighbor spacing by TILE_SPACING_PX without changing hex art size.
func _spacing_scale(tile_positions: Dictionary) -> float:
	var neighbor_dist := _min_neighbor_distance(tile_positions)
	if not is_finite(neighbor_dist) or neighbor_dist <= 0.0:
		return 1.0
	return (neighbor_dist + TILE_SPACING_PX) / neighbor_dist


func _measure_content_size(
	tile_positions: Dictionary,
	min_pos: Vector2,
	spacing_scale: float,
	tile_size: Vector2
) -> Vector2:
	var layout_max := Vector2.ZERO
	for origin: Vector2 in tile_positions.values():
		var placed: Vector2 = (origin - min_pos) * spacing_scale
		layout_max = layout_max.max(placed + tile_size)
	return layout_max


func _make_tile_host(tile_size: Vector2, coords: Vector2i) -> Control:
	var host := Control.new()
	host.custom_minimum_size = tile_size
	host.size = tile_size
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.mouse_default_cursor_shape = Control.CURSOR_HELP
	host.mouse_entered.connect(_on_tile_mouse_entered.bind(coords))
	host.mouse_exited.connect(_on_tile_mouse_exited.bind(coords))

	var tile := TextureRect.new()
	tile.texture = _texture_for_coords(coords)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(tile)
	return host


func _texture_for_coords(coords: Vector2i) -> Texture2D:
	var is_start := _preview_map.is_first_tile_in_segment(coords)
	var is_end := _preview_map.is_last_tile_in_segment(coords)
	if is_start and is_end:
		return TILE_SEGMENT_BOTH
	if is_start:
		return TILE_SEGMENT_START
	if is_end:
		return TILE_SEGMENT_END
	return TILE_NORMAL


func _place_card_icon(host: Control, tile_size: Vector2, card_id: String) -> void:
	var card := GameManager.get_tile_card_by_id(card_id)
	var icon: CardIcon = CARD_ICON_SCENE.instantiate()
	# CardIcon.tscn uses full-rect anchors. Pin top-left so size matches this hex.
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon.anchor_right = 0.0
	icon.anchor_bottom = 0.0
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.custom_minimum_size = tile_size
	icon.size = tile_size
	icon.position = Vector2.ZERO
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(icon)
	icon.setup(card)


func _apply_occupancy_modulate(host: Control, coords: Vector2i, card_id: String) -> void:
	if _disabled_coords.has(coords):
		host.modulate = DISABLED_MODULATE
	elif card_id.is_empty():
		host.modulate = EMPTY_MODULATE


func _update_content_transform() -> void:
	if _content == null or _content_size.x <= 0.0 or _content_size.y <= 0.0:
		return
	if _map_host == null or _map_host.size.x <= 0.0 or _map_host.size.y <= 0.0:
		return
	var fit_scale := minf(_map_host.size.x / _content_size.x, _map_host.size.y / _content_size.y)
	fit_scale = minf(fit_scale, MAX_CONTENT_SCALE)
	_content.scale = Vector2(fit_scale, fit_scale)
	_content.position = (_map_host.size - _content_size * fit_scale) * 0.5


func _min_neighbor_distance(tile_positions: Dictionary) -> float:
	var min_dist := INF
	var positions: Array = tile_positions.values()
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			var dist: float = (positions[i] as Vector2).distance_to(positions[j] as Vector2)
			if dist > 0.0 and dist < min_dist:
				min_dist = dist
	return min_dist


func _on_tile_mouse_entered(coords: Vector2i) -> void:
	_hover_coords = coords
	_refresh_caption()
	var card := _card_at(coords)
	if card == null:
		return
	var host: Control = _tiles.get(coords)
	if host == null:
		return
	var tip := card.name
	if not card.description.is_empty():
		tip += "\n%s" % card.description
	EventBus.toggle_tooltip.emit(true, tip, host.get_global_rect())


func _on_tile_mouse_exited(coords: Vector2i) -> void:
	if _hover_coords != coords:
		return
	_hover_coords = NO_HOVER
	EventBus.toggle_tooltip.emit(false, "")
	_refresh_caption()


func _refresh_caption() -> void:
	if _placed_by_coords.is_empty():
		_set_caption("Empty board")
		return
	var hovered := _card_at(_hover_coords)
	if hovered != null:
		_set_caption(hovered.name)
		return
	_set_caption("%d cards on the board" % _placed_by_coords.size())


func _set_caption(text: String) -> void:
	if _caption_label == null:
		return
	_caption_label.text = text


func _card_at(coords: Vector2i) -> TileCard:
	var card_id := String(_placed_by_coords.get(coords, ""))
	if card_id.is_empty():
		return null
	return GameManager.get_tile_card_by_id(card_id)


func _parse_placed_cards(placed: Variant) -> Dictionary:
	var result: Dictionary = {}
	if placed is not Array:
		return result
	for entry: Variant in placed:
		if entry is not Dictionary:
			continue
		var coords := _coords_from_array(entry.get("coords", []))
		var card_id := String(entry.get("card_id", ""))
		if coords == NO_HOVER or card_id.is_empty():
			continue
		result[coords] = card_id
	return result


func _parse_disabled_coords(disabled: Variant) -> Dictionary:
	var result: Dictionary = {}
	if disabled is not Array:
		return result
	for coords_data: Variant in disabled:
		var coords := _coords_from_array(coords_data)
		if coords == NO_HOVER:
			continue
		result[coords] = true
	return result


func _coords_from_array(coords_data: Variant) -> Vector2i:
	if coords_data is not Array or coords_data.size() < 2:
		return NO_HOVER
	return Vector2i(int(coords_data[0]), int(coords_data[1]))
