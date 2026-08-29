class_name TriggerOrderOverlay
extends Node2D

# Runtime labels for trigger order. Numbers are Controls so they can sit above cards.

const MARKER_SCENE := preload("res://scenes/ui/trigger_order_marker.tscn")

var _map: HexTileMap
var _built: bool = false
var _markers_by_coords: Dictionary = {}
var _full_reveal: bool = false
var _focus_coords: Vector2i = Vector2i(-1, -1)
var _focus_include_center: bool = true


func setup(map: HexTileMap) -> void:
	_map = map
	visible = false
	z_index = 25


func rebuild() -> void:
	for child in get_children():
		child.free()
	_built = false
	_markers_by_coords.clear()
	if _map == null:
		return

	var order := 1
	for coords: Vector2i in _map.get_coords_in_trigger_order():
		var marker: TriggerOrderMarker = MARKER_SCENE.instantiate()
		add_child(marker)
		marker.position = _map.base_layer.map_to_local(coords) - Hex.HEX_TILE_HALF
		marker.setup(
			order,
			_map.is_first_tile_in_segment(coords),
			_map.is_last_tile_in_segment(coords)
		)
		_markers_by_coords[coords] = marker
		order += 1
	_built = true
	_apply_display_state()


## Reapply visibility and backdrops after map occupancy changes.
func refresh_display_state() -> void:
	_apply_display_state()


## Sticky layout toggle or Tab peek. Shows every trigger index on top of the cards.
func set_full_reveal(active: bool) -> void:
	# Hover refreshes call this every cell change. Reapply only on a real on/off flip.
	if _full_reveal == active:
		return
	_full_reveal = active
	_apply_display_state()


## Focus one segment. include_center false hides the hovered tile's number.
func set_focus_coords(coords: Vector2i, include_center: bool = true) -> void:
	if _focus_coords == coords and _focus_include_center == include_center:
		return
	_focus_coords = coords
	_focus_include_center = include_center
	_apply_display_state()


func clear_focus() -> void:
	if _focus_coords == Vector2i(-1, -1):
		return
	_focus_coords = Vector2i(-1, -1)
	_focus_include_center = true
	_apply_display_state()


func _apply_display_state() -> void:
	if not _built:
		return

	visible = _full_reveal or _focus_coords != Vector2i(-1, -1)
	if not visible:
		return

	var focus_segment: Array[Vector2i] = []
	if _focus_coords != Vector2i(-1, -1):
		focus_segment = _get_focus_segment_coords(_focus_coords)

	for coords: Vector2i in _markers_by_coords.keys():
		var marker: TriggerOrderMarker = _markers_by_coords[coords]
		var in_focus_segment := coords in focus_segment
		var is_focus_cell := coords == _focus_coords
		# Full reveal, or this tile's segment. Numbers stay above hex fills.
		var show_number := _full_reveal or (in_focus_segment and (_focus_include_center or not is_focus_cell))
		marker.set_number_backdrop_visible(show_number and _coords_has_card(coords))
		marker.set_number_visible(show_number)


func _coords_has_card(coords: Vector2i) -> bool:
	if not _map.map_data.has(coords):
		return false
	return _map.map_data[coords].active_tile_card != null


func _get_focus_segment_coords(coords: Vector2i) -> Array[Vector2i]:
	var segment_coords: Array[Vector2i] = []
	var segment_index := _map.get_segment_index(coords)
	if segment_index < 0:
		return segment_coords
	for hex: Hex in _map.get_hexes_in_segment(segment_index):
		segment_coords.append(hex.coordinates)
	return segment_coords
