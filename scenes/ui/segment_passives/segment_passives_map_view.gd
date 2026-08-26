class_name SegmentPassivesMapView
extends Control

## Hex grid of plain loadout tiles. Segment grouping still comes from the character map.

signal segment_selected(segment_index: int)
signal passive_remove_requested(segment_index: int, list_index: int)
signal passive_drop_requested(segment_index: int, passive_id: String)
signal passive_move_requested(
	from_segment: int,
	from_list_index: int,
	to_segment: int,
	to_coords: Vector2i
)

const DRAG_KIND := "segment_passive"
const DRAG_KIND_BOARD := "placed_segment_passive"

const SEGMENT_PASSIVES_PREVIEW_MAP = preload("res://scenes/ui/segment_passives/segment_passives_preview_map.tscn")
const PASSIVES_TILE = preload("uid://ccxxa581gp0it")

const MAX_CONTENT_SCALE := 1.0
const HIGHLIGHT_SELECTED := Color(0.7, 0.88, 1.0, 1.0)
const SELECTED_BLEND := 0.72
const HIGHLIGHT_HOVER := Color(0.82, 0.92, 1.0, 1.0)
const HOVER_BLEND := 0.38

const PLACEMENT_POP_SCALE := 1.16
const PLACEMENT_SLAM_DURATION := 0.16
const PLACEMENT_SETTLE_DURATION := 0.18
const PLACEMENT_STAGGER := 0.05

var _character: CharacterDefinition = null
var _set_id: String = "A"
var _preview_map: SegmentPassivesPreviewMap = null
# Authored-size hex grid. Scaled as a unit so the 37 tiles always fit the panel.
var _content: Control = null
var _content_size: Vector2 = Vector2.ZERO
var _tiles: Dictionary = {}
var _tile_segments: Dictionary = {}
var _tile_icons: Dictionary = {}
# Slot index of the placed passive occupying each tile, or -1 when empty.
var _tile_placement_index: Dictionary = {}
var _selected_segment_index: int = -1
var _hover_segment_index: int = -1
var _placement_tweens: Array[Tween] = []


func _ready() -> void:
	clip_contents = true
	resized.connect(_update_content_transform)


func setup(character: CharacterDefinition, set_id: String) -> void:
	_character = character
	_set_id = set_id
	_rebuild_map()


func get_segment_capacity(segment_index: int) -> int:
	if _preview_map == null:
		return 0
	return _preview_map.get_segment_size(segment_index)


func refresh_placements() -> void:
	_refresh_passive_overlays()
	_refresh_segment_highlights()


func get_tile_placement_index(coords: Vector2i) -> int:
	return int(_tile_placement_index.get(coords, -1))


func cleanup() -> void:
	if _preview_map != null:
		_preview_map.restore_character_context()


func _rebuild_map() -> void:
	_kill_placement_tweens()
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	_tile_segments.clear()
	_tile_icons.clear()
	_tile_placement_index.clear()
	_selected_segment_index = -1
	_hover_segment_index = -1
	_content = null

	if _character == null:
		return

	# Hidden layout source. Keeps character segment grouping without drawing the gameplay map.
	_preview_map = SEGMENT_PASSIVES_PREVIEW_MAP.instantiate() as SegmentPassivesPreviewMap
	_preview_map.visible = false
	_preview_map.modulate.a = 0.0
	add_child(_preview_map)
	_preview_map.setup_character(_character)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var tile_size := _preview_map.get_tile_pixel_size()
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var tile_positions: Dictionary = {}
	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		var tile_pos := _preview_map.local_position_for_coords(coords)
		tile_positions[coords] = tile_pos
		min_pos = min_pos.min(tile_pos)
		max_pos = max_pos.max(tile_pos + tile_size)

	if not is_finite(min_pos.x):
		return

	_content_size = max_pos - min_pos
	_content.custom_minimum_size = _content_size
	_content.size = _content_size

	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		var segment_index: int = _preview_map.get_segment_index(coords)
		var tile := _make_tile_button(tile_size, segment_index, coords)
		tile.position = tile_positions[coords] - min_pos
		tile.gui_input.connect(_on_tile_gui_input.bind(segment_index, coords))
		tile.mouse_entered.connect(_on_tile_mouse_entered.bind(segment_index))
		tile.mouse_exited.connect(_on_tile_mouse_exited.bind(segment_index))
		_content.add_child(tile)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2.ZERO
		icon.size = tile_size
		icon.visible = false
		tile.add_child(icon)

		_tiles[coords] = tile
		_tile_segments[coords] = segment_index
		_tile_icons[coords] = icon

	_update_content_transform()
	_refresh_passive_overlays()
	_refresh_segment_highlights()


func _make_tile_button(tile_size: Vector2, segment_index: int, coords: Vector2i) -> HexTile:
	var tile := HexTile.new()
	tile.host = self
	tile.segment_index = segment_index
	tile.coords = coords
	tile.texture = PASSIVES_TILE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.custom_minimum_size = tile_size
	tile.size = tile_size
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return tile


## Scales the authored hex grid down so all 37 tiles fit the available panel.
func _update_content_transform() -> void:
	if _content == null or _content_size.x <= 0.0 or _content_size.y <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var fit_scale := minf(size.x / _content_size.x, size.y / _content_size.y)
	fit_scale = minf(fit_scale, MAX_CONTENT_SCALE)
	_content.scale = Vector2(fit_scale, fit_scale)
	_content.position = (size - _content_size * fit_scale) * 0.5


func _on_tile_gui_input(event: InputEvent, segment_index: int, coords: Vector2i) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_selected_segment_index = segment_index
		_refresh_segment_highlights()
		segment_selected.emit(segment_index)
		return
	if event.button_index != MOUSE_BUTTON_RIGHT:
		return
	# Right-click selects the segment. Occupied tiles also strip that placed passive.
	_selected_segment_index = segment_index
	_refresh_segment_highlights()
	var list_index: int = int(_tile_placement_index.get(coords, -1))
	if list_index < 0:
		segment_selected.emit(segment_index)
		return
	passive_remove_requested.emit(segment_index, list_index)


func _on_tile_mouse_entered(segment_index: int) -> void:
	_hover_segment_index = segment_index
	_refresh_segment_highlights()


func _on_tile_mouse_exited(segment_index: int) -> void:
	if _hover_segment_index == segment_index:
		_hover_segment_index = -1
	_refresh_segment_highlights()


func _refresh_segment_highlights() -> void:
	for coords: Vector2i in _tiles.keys():
		var tile: TextureRect = _tiles[coords]
		var segment_index: int = _tile_segments[coords]
		var color := Color.WHITE
		# Selected uses a stronger blue. Hover adds a faint blue overlay on top.
		if segment_index == _selected_segment_index:
			color = color.lerp(HIGHLIGHT_SELECTED, SELECTED_BLEND)
		if segment_index == _hover_segment_index:
			color = color.lerp(HIGHLIGHT_HOVER, HOVER_BLEND)
		tile.modulate = color


func _refresh_passive_overlays() -> void:
	if _character == null or _preview_map == null:
		return

	for coords: Vector2i in _tiles.keys():
		_tile_placement_index[coords] = -1
		var icon: TextureRect = _tile_icons[coords]
		icon.visible = false
		icon.texture = null
		icon.scale = Vector2.ONE
		icon.modulate = Color.WHITE

	var segments := MetaProgressionManager.get_segment_placements(_character.id, _set_id)
	for segment_key: String in segments.keys():
		var passive_ids: Variant = segments[segment_key]
		if passive_ids is Array:
			_paint_segment_passives(int(segment_key), passive_ids)


## Paints one icon per occupied slot. Multi-tile passives repeat across the segment.
func _paint_segment_passives(segment_index: int, passive_ids: Array) -> void:
	var segment_coords: Array[Vector2i] = []
	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		if _preview_map.get_segment_index(coords) == segment_index:
			segment_coords.append(coords)
	if segment_coords.is_empty():
		return

	var slot_index := 0
	for list_index in passive_ids.size():
		var passive := MetaProgressionManager.get_passive_by_id(String(passive_ids[list_index]))
		if passive == null:
			continue
		for _slot in range(maxi(1, passive.tile_cost)):
			if slot_index >= segment_coords.size():
				break
			var coords := segment_coords[slot_index]
			slot_index += 1
			var icon: TextureRect = _tile_icons.get(coords)
			if icon == null:
				continue
			_tile_placement_index[coords] = list_index
			icon.texture = passive.icon
			icon.visible = true


## Pops newly placed icons onto their hexes. No camera shake.
func play_placement_animation(segment_index: int, list_index: int) -> void:
	_kill_placement_tweens()
	var delay := 0.0
	var played_sound := false
	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		if _preview_map.get_segment_index(coords) != segment_index:
			continue
		if int(_tile_placement_index.get(coords, -1)) != list_index:
			continue
		var tile: Control = _tiles.get(coords)
		var icon: Control = _tile_icons.get(coords)
		if tile == null or icon == null:
			continue
		if not played_sound:
			played_sound = true
			AudioManager.play_sfx(UISounds.PASSIVE_PLACEMENT, 0.5, 0.35)
		_play_tile_placement_tween(tile, icon, delay)
		delay += PLACEMENT_STAGGER


func _play_tile_placement_tween(tile: Control, icon: Control, delay: float) -> void:
	tile.pivot_offset = tile.size * 0.5
	icon.pivot_offset = icon.size * 0.5
	tile.scale = Vector2(0.82, 0.82)
	icon.scale = Vector2(0.15, 0.15)
	icon.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.chain().set_parallel(true)
	tween.tween_property(tile, "scale", Vector2(PLACEMENT_POP_SCALE, PLACEMENT_POP_SCALE), PLACEMENT_SLAM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2(PLACEMENT_POP_SCALE, PLACEMENT_POP_SCALE), PLACEMENT_SLAM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "modulate:a", 1.0, PLACEMENT_SLAM_DURATION * 0.7)
	tween.chain().set_parallel(true)
	tween.tween_property(tile, "scale", Vector2.ONE, PLACEMENT_SETTLE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "scale", Vector2.ONE, PLACEMENT_SETTLE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_placement_tweens.append(tween)


func _kill_placement_tweens() -> void:
	for tween in _placement_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_placement_tweens.clear()
	for coords: Vector2i in _tiles.keys():
		var tile: Control = _tiles[coords]
		var icon: Control = _tile_icons[coords]
		if tile != null:
			tile.scale = Vector2.ONE
		if icon != null:
			icon.scale = Vector2.ONE
			icon.modulate.a = 1.0 if icon.visible else 0.0


func can_accept_passive_drop(data: Variant, segment_index: int, coords: Vector2i) -> bool:
	if _character == null or not data is Dictionary:
		return false
	_hover_segment_index = segment_index
	_refresh_segment_highlights()
	var kind := String(data.get("kind", ""))
	if kind == DRAG_KIND:
		var passive_id := String(data.get("passive_id", ""))
		if passive_id.is_empty():
			return false
		return MetaProgressionManager.can_place_passive(
			_character.id,
			_set_id,
			segment_index,
			passive_id,
			get_segment_capacity(segment_index)
		)
	if kind != DRAG_KIND_BOARD:
		return false
	return MetaProgressionManager.can_relocate_passive(
		_character.id,
		_set_id,
		int(data.get("from_segment", -1)),
		int(data.get("from_list_index", -1)),
		segment_index,
		int(_tile_placement_index.get(coords, -1)),
		get_segment_capacity(segment_index)
	)


func accept_passive_drop(data: Variant, segment_index: int, coords: Vector2i) -> void:
	if not data is Dictionary:
		return
	_selected_segment_index = segment_index
	_refresh_segment_highlights()
	var kind := String(data.get("kind", ""))
	if kind == DRAG_KIND:
		var passive_id := String(data.get("passive_id", ""))
		if not passive_id.is_empty():
			passive_drop_requested.emit(segment_index, passive_id)
		return
	if kind == DRAG_KIND_BOARD:
		passive_move_requested.emit(
			int(data.get("from_segment", -1)),
			int(data.get("from_list_index", -1)),
			segment_index,
			coords
		)


## Starts a board drag from an occupied hex. Empty tiles do not drag.
func begin_board_drag(coords: Vector2i) -> Variant:
	var list_index: int = int(_tile_placement_index.get(coords, -1))
	if list_index < 0 or _character == null:
		return null
	var segment_index: int = int(_tile_segments.get(coords, -1))
	var placed := MetaProgressionManager.get_placed_passive_ids(_character.id, _set_id, segment_index)
	if list_index >= placed.size():
		return null
	var passive := MetaProgressionManager.get_passive_by_id(placed[list_index])
	if passive == null or passive.icon == null:
		return null
	return {
		"kind": DRAG_KIND_BOARD,
		"passive_id": passive.id,
		"from_segment": segment_index,
		"from_list_index": list_index,
		"icon": passive.icon,
	}


func _apply_icon_drag_preview(source: Control, icon_texture: Texture2D) -> void:
	var preview := TextureRect.new()
	preview.texture = icon_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(72.0, 72.0)
	preview.size = Vector2(72.0, 72.0)
	preview.modulate.a = 0.92
	preview.position = Vector2(-36.0, -36.0)
	var preview_root := Control.new()
	preview_root.add_child(preview)
	source.set_drag_preview(preview_root)


## One hex on the loadout map. Forwards drag-and-drop to the map view.
class HexTile extends TextureRect:
	var host: SegmentPassivesMapView
	var segment_index: int = -1
	var coords := Vector2i.ZERO

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if host == null:
			return null
		var data: Variant = host.begin_board_drag(coords)
		if not data is Dictionary:
			return null
		var payload: Dictionary = data
		var icon_texture: Texture2D = payload.get("icon") as Texture2D
		if icon_texture == null:
			return null
		host._apply_icon_drag_preview(self, icon_texture)
		payload.erase("icon")
		return payload

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if host == null:
			return false
		return host.can_accept_passive_drop(data, segment_index, coords)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if host != null:
			host.accept_passive_drop(data, segment_index, coords)
