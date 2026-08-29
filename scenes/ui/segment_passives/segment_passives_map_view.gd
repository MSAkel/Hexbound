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
# Pause overlay can cap this so the hex cluster stays compact.
var max_content_scale: float = MAX_CONTENT_SCALE
const HIGHLIGHT_SELECTED := Color(0.7, 0.88, 1.0, 1.0)
const SELECTED_BLEND := 0.72
const HIGHLIGHT_HOVER := Color(0.82, 0.92, 1.0, 1.0)
const HOVER_BLEND := 0.38

const PLACEMENT_POP_SCALE := 1.16
const PLACEMENT_SLAM_DURATION := 0.16
const PLACEMENT_SETTLE_DURATION := 0.18
const PLACEMENT_STAGGER := 0.05
# Ghost icons on tiles a dragged passive would occupy.
const DROP_PREVIEW_ALPHA := 0.42

var _character: CharacterDefinition = null
var _set_id: String = "A"
# Pause-menu inspector uses this. Clicks, drags, and right-click remove stay off.
var read_only: bool = false
var _preview_map: SegmentPassivesPreviewMap = null
# Authored-size hex grid. Scaled as a unit so the 37 tiles always fit the panel.
var _content: Control = null
var _content_size: Vector2 = Vector2.ZERO
var _tiles: Dictionary = {}
var _tile_segments: Dictionary = {}
var _tile_icons: Dictionary = {}
# Faint occupancy preview drawn above placed icons while dragging.
var _tile_ghosts: Dictionary = {}
# Slot index of the placed passive occupying each tile, or -1 when empty.
var _tile_placement_index: Dictionary = {}
var _selected_segment_index: int = -1
var _hover_segment_index: int = -1
var _hover_coords := Vector2i(-999, -999)
var _placement_tweens: Array[Tween] = []
# Cache so _can_drop_data mouse-moves do not rebuild the same ghosts.
var _drop_preview_key: String = ""


func _ready() -> void:
	clip_contents = true
	# Tiles handle input. The view itself must not eat clicks outside the hexes.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_update_content_transform)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_drop_preview()


func setup(character: CharacterDefinition, set_id: String) -> void:
	_character = character
	_set_id = set_id
	_rebuild_map()


func get_segment_capacity(segment_index: int) -> int:
	if _preview_map == null:
		return 0
	return _preview_map.get_segment_size(segment_index)


func refresh_placements() -> void:
	_clear_drop_preview()
	_refresh_passive_overlays()
	_refresh_segment_highlights()
	# Placement can change under a stationary cursor. Refresh the hover panel.
	if _tiles.has(_hover_coords):
		_show_placed_passive_tooltip(_hover_coords)


func get_tile_placement_index(coords: Vector2i) -> int:
	return int(_tile_placement_index.get(coords, -1))


func cleanup() -> void:
	_hide_placed_passive_tooltip()
	_kill_placement_tweens()
	_release_tile_hosts()
	if _preview_map != null:
		_preview_map.restore_character_context()
		_preview_map = null
	_content = null
	_tiles.clear()
	_tile_segments.clear()
	_tile_icons.clear()
	_tile_ghosts.clear()
	_tile_placement_index.clear()
	_drop_preview_key = ""


func _exit_tree() -> void:
	cleanup()


## Break HexTile.host cycles so the debugger does not report ObjectDB leaks on leave.
func _release_tile_hosts() -> void:
	for coords: Vector2i in _tiles.keys():
		var tile: Variant = _tiles[coords]
		if tile is HexTile:
			(tile as HexTile).host = null


func _rebuild_map() -> void:
	_kill_placement_tweens()
	_release_tile_hosts()
	if _preview_map != null:
		_preview_map.restore_character_context()
		_preview_map = null
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	_tile_segments.clear()
	_tile_icons.clear()
	_tile_ghosts.clear()
	_tile_placement_index.clear()
	_drop_preview_key = ""
	_selected_segment_index = -1
	_hover_segment_index = -1
	_hover_coords = Vector2i(-999, -999)
	_hide_placed_passive_tooltip()
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
		tile.mouse_entered.connect(_on_tile_mouse_entered.bind(segment_index, coords))
		tile.mouse_exited.connect(_on_tile_mouse_exited.bind(segment_index, coords))
		_content.add_child(tile)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2.ZERO
		icon.size = tile_size
		icon.visible = false
		tile.add_child(icon)

		var ghost := TextureRect.new()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.position = Vector2.ZERO
		ghost.size = tile_size
		ghost.visible = false
		ghost.modulate = Color(1.0, 1.0, 1.0, DROP_PREVIEW_ALPHA)
		tile.add_child(ghost)

		_tiles[coords] = tile
		_tile_segments[coords] = segment_index
		_tile_icons[coords] = icon
		_tile_ghosts[coords] = ghost

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
	# Read-only still needs hover for tooltips, but it should not look clickable.
	tile.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if read_only else Control.CURSOR_POINTING_HAND
	)
	return tile


## Scales the authored hex grid down so all 37 tiles fit the available panel.
func _update_content_transform() -> void:
	if _content == null or _content_size.x <= 0.0 or _content_size.y <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var fit_scale := minf(size.x / _content_size.x, size.y / _content_size.y)
	fit_scale = minf(fit_scale, max_content_scale)
	_content.scale = Vector2(fit_scale, fit_scale)
	_content.position = (size - _content_size * fit_scale) * 0.5


func _on_tile_gui_input(event: InputEvent, segment_index: int, coords: Vector2i) -> void:
	if read_only:
		return
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


func _on_tile_mouse_entered(segment_index: int, coords: Vector2i) -> void:
	_hover_segment_index = segment_index
	_hover_coords = coords
	_refresh_segment_highlights()
	_show_placed_passive_tooltip(coords)


func _on_tile_mouse_exited(segment_index: int, coords: Vector2i) -> void:
	if _hover_segment_index == segment_index:
		_hover_segment_index = -1
	if _hover_coords == coords:
		_hover_coords = Vector2i(-999, -999)
	_refresh_segment_highlights()
	_hide_placed_passive_tooltip()
	# Wait a frame so hopping to a neighbor hex does not flash the ghosts off.
	call_deferred("_clear_drop_preview_if_cursor_left_map")


## Name and description for a placed passive. Empty tiles hide the panel.
func _show_placed_passive_tooltip(coords: Vector2i) -> void:
	var passive := _get_placed_passive_at(coords)
	var tile: Control = _tiles.get(coords)
	if passive == null or tile == null:
		_hide_placed_passive_tooltip()
		return
	var body := passive.description
	if body.is_empty():
		body = passive.get_effect_summary()
	var text := passive.display_name if body.is_empty() else "%s\n%s" % [passive.display_name, body]
	EventBus.toggle_tooltip.emit(true, text, tile.get_global_rect())


func _hide_placed_passive_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _get_placed_passive_at(coords: Vector2i) -> SegmentPassive:
	var list_index: int = int(_tile_placement_index.get(coords, -1))
	if list_index < 0 or _character == null:
		return null
	var segment_index: int = int(_tile_segments.get(coords, -1))
	var placed := MetaProgressionManager.get_placed_passive_ids(_character.id, _set_id, segment_index)
	if list_index >= placed.size():
		return null
	return MetaProgressionManager.get_passive_by_id(placed[list_index])


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
		_clear_drop_preview()
		return false
	_hover_segment_index = segment_index
	_refresh_segment_highlights()
	var kind := String(data.get("kind", ""))
	var can_drop := false
	if kind == DRAG_KIND:
		var passive_id := String(data.get("passive_id", ""))
		if not passive_id.is_empty():
			can_drop = MetaProgressionManager.can_place_passive(
				_character.id,
				_set_id,
				segment_index,
				passive_id,
				get_segment_capacity(segment_index)
			)
	elif kind == DRAG_KIND_BOARD:
		can_drop = MetaProgressionManager.can_relocate_passive(
			_character.id,
			_set_id,
			int(data.get("from_segment", -1)),
			int(data.get("from_list_index", -1)),
			segment_index,
			int(_tile_placement_index.get(coords, -1)),
			get_segment_capacity(segment_index)
		)
	_update_drop_preview(data, segment_index, coords, can_drop)
	return can_drop


func accept_passive_drop(data: Variant, segment_index: int, coords: Vector2i) -> void:
	if not data is Dictionary:
		return
	_clear_drop_preview()
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


## Shows the dragged passive icon on the hexes it would occupy if dropped here.
func _update_drop_preview(data: Dictionary, segment_index: int, coords: Vector2i, can_drop: bool) -> void:
	if not can_drop:
		_clear_drop_preview()
		return
	var kind := String(data.get("kind", ""))
	var dest_list_index: int = int(_tile_placement_index.get(coords, -1))
	var preview_key := "%s:%s:%d:%d" % [
		kind,
		String(data.get("passive_id", "")),
		segment_index,
		dest_list_index if kind == DRAG_KIND_BOARD else -1,
	]
	if preview_key == _drop_preview_key:
		return
	var occupancy := _get_drop_occupancy_coords(data, segment_index, coords)
	var passive := MetaProgressionManager.get_passive_by_id(String(data.get("passive_id", "")))
	if occupancy.is_empty() or passive == null or passive.icon == null:
		_clear_drop_preview()
		return
	_clear_drop_preview()
	_drop_preview_key = preview_key
	for occupy_coords: Vector2i in occupancy:
		var ghost: TextureRect = _tile_ghosts.get(occupy_coords)
		if ghost == null:
			continue
		ghost.texture = passive.icon
		ghost.modulate = Color(1.0, 1.0, 1.0, DROP_PREVIEW_ALPHA)
		ghost.visible = true


func _clear_drop_preview() -> void:
	_drop_preview_key = ""
	for coords: Vector2i in _tile_ghosts.keys():
		var ghost: TextureRect = _tile_ghosts[coords]
		if ghost == null:
			continue
		ghost.visible = false
		ghost.texture = null


func _clear_drop_preview_if_cursor_left_map() -> void:
	var mouse := get_global_mouse_position()
	for coords: Vector2i in _tiles.keys():
		var tile: Control = _tiles[coords]
		if tile != null and tile.get_global_rect().has_point(mouse):
			return
	_clear_drop_preview()


## Tile span the drop would take. List drops append. Board drops append or take the dest slot.
func _get_drop_occupancy_coords(data: Dictionary, segment_index: int, coords: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if _preview_map == null or _character == null:
		return empty
	var kind := String(data.get("kind", ""))
	var segment_coords := _get_segment_coords(segment_index)
	if segment_coords.is_empty():
		return empty
	if kind == DRAG_KIND:
		var dest_ids := MetaProgressionManager.get_placed_passive_ids(
			_character.id, _set_id, segment_index
		)
		return _coords_after_append(segment_coords, dest_ids, String(data.get("passive_id", "")))
	if kind != DRAG_KIND_BOARD:
		return empty
	var from_segment: int = int(data.get("from_segment", -1))
	var from_list_index: int = int(data.get("from_list_index", -1))
	var dragged_id := String(data.get("passive_id", ""))
	var dest_list_index: int = int(_tile_placement_index.get(coords, -1))
	var dest_ids := MetaProgressionManager.get_placed_passive_ids(
		_character.id, _set_id, segment_index
	)
	var simulated: Array = []
	for passive_id: String in dest_ids:
		simulated.append(passive_id)
	if dest_list_index < 0:
		return _coords_after_append(segment_coords, simulated, dragged_id)
	if from_segment == segment_index:
		if from_list_index < 0 or from_list_index >= simulated.size():
			return empty
		if dest_list_index >= simulated.size():
			return empty
		var target_id: String = String(simulated[dest_list_index])
		simulated[from_list_index] = target_id
		simulated[dest_list_index] = dragged_id
		return _coords_for_list_index(segment_coords, simulated, dest_list_index)
	if dest_list_index >= simulated.size():
		return empty
	simulated[dest_list_index] = dragged_id
	return _coords_for_list_index(segment_coords, simulated, dest_list_index)


func _get_segment_coords(segment_index: int) -> Array[Vector2i]:
	var segment_coords: Array[Vector2i] = []
	if _preview_map == null:
		return segment_coords
	for coords: Vector2i in _preview_map.get_coords_in_trigger_order():
		if _preview_map.get_segment_index(coords) == segment_index:
			segment_coords.append(coords)
	return segment_coords


func _coords_after_append(
	segment_coords: Array[Vector2i],
	passive_ids: Array,
	passive_id: String
) -> Array[Vector2i]:
	var slot := _used_slots_from_ids(passive_ids)
	return _slice_segment_coords(segment_coords, slot, _tile_cost_for_id(passive_id))


func _coords_for_list_index(
	segment_coords: Array[Vector2i],
	passive_ids: Array,
	list_index: int
) -> Array[Vector2i]:
	var slot := 0
	for index in passive_ids.size():
		var cost := _tile_cost_for_id(String(passive_ids[index]))
		if index == list_index:
			return _slice_segment_coords(segment_coords, slot, cost)
		slot += cost
	return []


func _slice_segment_coords(segment_coords: Array[Vector2i], start: int, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in count:
		var index := start + offset
		if index < 0 or index >= segment_coords.size():
			break
		result.append(segment_coords[index])
	return result


func _used_slots_from_ids(passive_ids: Array) -> int:
	var used := 0
	for entry in passive_ids:
		used += _tile_cost_for_id(String(entry))
	return used


func _tile_cost_for_id(passive_id: String) -> int:
	var passive := MetaProgressionManager.get_passive_by_id(passive_id)
	if passive == null:
		return 0
	return maxi(1, passive.tile_cost)


## Starts a board drag from an occupied hex. Empty tiles do not drag.
func begin_board_drag(coords: Vector2i) -> Variant:
	_hide_placed_passive_tooltip()
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
		if host == null or host.read_only:
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
		if host == null or host.read_only:
			return false
		return host.can_accept_passive_drop(data, segment_index, coords)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if host == null or host.read_only:
			return
		host.accept_passive_drop(data, segment_index, coords)
