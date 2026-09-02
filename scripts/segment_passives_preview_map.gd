class_name SegmentPassivesPreviewMap
extends Node2D

## Editor-authored hex layout for the segment passives screen. No gameplay simulation.

@onready var base_layer: TileMapLayer = $BaseLayer

var character: CharacterDefinition = null
var map_data: Dictionary = {}
var hex_size: int = 3
var _layout: HexMapLayout
var _saved_character: CharacterDefinition = null


func _ready() -> void:
	_ensure_layout()


func setup_character(character_def: CharacterDefinition) -> void:
	_ensure_layout()
	character = character_def
	_saved_character = GameManager.selected_character
	GameManager.selected_character = character_def
	_sync_map_data_from_tiles()


func get_layout_character() -> CharacterDefinition:
	return character


func restore_character_context() -> void:
	if _saved_character != null:
		GameManager.selected_character = _saved_character
	_saved_character = null


func get_coords_in_trigger_order() -> Array[Vector2i]:
	return _layout.get_coords_in_trigger_order()


func get_segment_index(coords: Vector2i) -> int:
	return _layout.get_segment_index(coords)


func is_first_tile_in_segment(coords: Vector2i) -> bool:
	return _layout.is_first_tile_in_segment(coords)


func is_last_tile_in_segment(coords: Vector2i) -> bool:
	return _layout.is_last_tile_in_segment(coords)


func get_segment_count() -> int:
	return _layout.build_segments().size()


func get_segment_size(segment_index: int) -> int:
	return _layout.get_segment_size(segment_index)


func local_position_for_coords(coords: Vector2i) -> Vector2:
	return base_layer.map_to_local(coords) - get_tile_pixel_size() * 0.5


## Bounding box of one hex cell. Matches the tileset, not the gameplay map tiles.
func get_tile_pixel_size() -> Vector2:
	if base_layer.tile_set == null:
		return Vector2.ZERO
	return Vector2(base_layer.tile_set.tile_size)


func _ensure_layout() -> void:
	if _layout != null:
		return
	_layout = HexMapLayout.new()
	_layout.setup(self)


## Builds Hex entries from the TileMapLayer cells authored in the scene.
func _sync_map_data_from_tiles() -> void:
	map_data.clear()
	for coords: Vector2i in base_layer.get_used_cells():
		map_data[coords] = Hex.new(coords)
	if map_data.is_empty():
		push_warning("SegmentPassivesPreviewMap: BaseLayer has no tiles. Paint the hex grid in the editor.")
		return
	var hex_center := _find_hex_center()
	_layout.reset(hex_center)
	hex_size = _compute_hex_size()
	_layout.reset_turn_results()


func _find_hex_center() -> Vector2i:
	var cells := base_layer.get_used_cells()
	var sum := Vector2.ZERO
	for coords: Vector2i in cells:
		sum += Vector2(coords)
	var average := sum / float(cells.size())
	var best: Vector2i = cells[0]
	var best_dist := INF
	for coords: Vector2i in cells:
		var dist := Vector2(coords).distance_squared_to(average)
		if dist < best_dist:
			best_dist = dist
			best = coords
	return best


func _compute_hex_size() -> int:
	var max_ring := 0
	for coords: Vector2i in map_data.keys():
		max_ring = maxi(max_ring, _layout.get_ring_distance(coords))
	return max_ring
