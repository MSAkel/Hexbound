class_name SegmentPassivesPreviewMap
extends Node2D

## Editor-authored hex layout for the segment passives screen. No gameplay simulation.

@onready var base_layer: TileMapLayer = $BaseLayer

var character: CharacterDefinition = null
var map_data: Dictionary = {}
var hex_size: int = 2
var _layout: HexMapLayout
var _saved_character: CharacterDefinition = null


func _ready() -> void:
	_ensure_layout()
	_apply_preview_tile_size()


func setup_character(character_def: CharacterDefinition) -> void:
	_ensure_layout()
	character = character_def
	_saved_character = GameManager.selected_character
	GameManager.selected_character = character_def
	_sync_map_data_from_tiles()


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


## Match gameplay hex pixels. Atlas region follows the PNG so placeholder art still slices as one tile.
func _apply_preview_tile_size() -> void:
	if base_layer == null or base_layer.tile_set == null:
		return
	base_layer.tile_set.tile_size = HexTileMap.HEX_TEXTURE_SIZE
	for i in base_layer.tile_set.get_source_count():
		var source := base_layer.tile_set.get_source(base_layer.tile_set.get_source_id(i))
		if source is TileSetAtlasSource:
			var atlas := source as TileSetAtlasSource
			if atlas.texture != null:
				atlas.texture_region_size = Vector2i(atlas.texture.get_size())
			else:
				atlas.texture_region_size = HexTileMap.HEX_TEXTURE_SIZE


func _ensure_layout() -> void:
	if _layout != null:
		return
	_layout = HexMapLayout.new()
	_layout.setup(self)


## Builds Hex entries for the shared 32-hex kitchen board.
func _sync_map_data_from_tiles() -> void:
	map_data.clear()
	base_layer.clear()
	var cells := HexMapLayout.compute_board_cells(base_layer)
	for coords: Vector2i in cells:
		map_data[coords] = Hex.new(coords)
		base_layer.set_cell(coords, 0, Vector2i(0, 0))
	if map_data.is_empty():
		push_warning("SegmentPassivesPreviewMap: failed to generate the kitchen board.")
		return
	var hex_center := HexMapLayout.board_hex_center(cells)
	_layout.reset(hex_center)
	var max_ring := 0
	for coords: Vector2i in map_data.keys():
		max_ring = maxi(max_ring, _layout.get_ring_distance(coords))
	hex_size = max_ring
	_layout.reset_turn_results()
