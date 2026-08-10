class_name HexMapLayout
extends RefCounted

# Ring distances, trigger-order sorting, and character segment grouping for a hex map.

const NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
]

var _map: HexTileMap
var _hex_center: Vector2i = Vector2i.ZERO
var _ring_distances: Dictionary = {}
var _segments_cache: Array[Array] = []
var _segments_cache_valid: bool = false
# Per-segment score and gold produced during the current turn resolution.
var _segment_turn_scores: Array[int] = []
var _segment_turn_multiplier: Array[int] = []
var _segment_turn_gold: Array[int] = []


## Binds this layout helper to a live map instance.
func setup(map: HexTileMap) -> void:
	_map = map


## Rebuilds ring distances and clears the segment cache after terrain generation.
func reset(hex_center: Vector2i) -> void:
	_hex_center = hex_center
	_ring_distances.clear()
	_invalidate_segments_cache()
	_compute_ring_distances()


## Map center tile used as the origin for ring distance calculations.
func get_hex_center() -> Vector2i:
	return _hex_center


## Ring index from the map center (0 = center, outer ring = map hex_size).
func get_ring_distance(coords: Vector2i) -> int:
	return _ring_distances.get(coords, -1)


## All map coordinates sorted by the active character trigger-order rule.
func get_coords_in_trigger_order() -> Array[Vector2i]:
	match GameManager.trigger_order:
		TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT:
			return _get_order_top_left_to_bottom_right()
		TriggerOrderType.Type.OUTER_RING_TO_INNER:
			return _get_order_outer_to_inner()
		TriggerOrderType.Type.CLOCKWISE_SPIRAL:
			return _get_order_clockwise_spiral()
		_:
			return _get_order_top_left_to_bottom_right()


## All map hex tiles in the same order as get_coords_in_trigger_order().
func get_hexes_in_trigger_order() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for coords: Vector2i in get_coords_in_trigger_order():
		hexes.append(_map.map_data[coords])
	return hexes


## Segment index for coords under the active character's row/ring grouping (-1 when unknown).
func get_segment_index(coords: Vector2i) -> int:
	var target_key: Variant = _get_segment_key(coords)
	for i in range(build_segments().size()):
		var segment: Array = build_segments()[i]
		if segment.is_empty():
			continue
		if _segment_keys_equal(_get_segment_key(segment[0]), target_key):
			return i
	return -1


## True when coords is the first tile in its segment (trigger-order start).
func is_first_tile_in_segment(coords: Vector2i) -> bool:
	var segment_index := get_segment_index(coords)
	if segment_index < 0:
		return false
	var segment: Array = build_segments()[segment_index]
	return not segment.is_empty() and segment[0] == coords


## True when coords is the last tile in its segment (trigger-order end).
func is_last_tile_in_segment(coords: Vector2i) -> bool:
	var segment_index := get_segment_index(coords)
	if segment_index < 0:
		return false
	var segment: Array = build_segments()[segment_index]
	return not segment.is_empty() and segment[segment.size() - 1] == coords


## First tile coordinates in a segment, or Vector2i(-1, -1) when the index is invalid.
func get_first_tile_coords_in_segment(segment_index: int) -> Vector2i:
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return Vector2i(-1, -1)
	var segment: Array = segments[segment_index]
	if segment.is_empty():
		return Vector2i(-1, -1)
	return segment[0]


## Last tile coordinates in a segment, or Vector2i(-1, -1) when the index is invalid.
func get_last_tile_coords_in_segment(segment_index: int) -> Vector2i:
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return Vector2i(-1, -1)
	var segment: Array = segments[segment_index]
	if segment.is_empty():
		return Vector2i(-1, -1)
	return segment[segment.size() - 1]


## Character-specific segment groups (each segment is an ordered list of coordinates).
func build_segments() -> Array[Array]:
	if _segments_cache_valid:
		return _segments_cache

	_segments_cache = _build_segments_uncached()
	_segments_cache_valid = true
	return _segments_cache


## All placed runes on one segment, optionally filtered by rune type.
func get_all_runes_on_segment(segment_index: int, filter_type: Variant = null) -> Array[Rune]:
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return []

	var result: Array[Rune] = []
	for coords: Vector2i in segments[segment_index]:
		var rune := _get_rune_on_coords(coords, filter_type)
		if rune != null:
			result.append(rune)
	return result


## All placed runes on other segments, optionally filtered by rune type.
func get_all_runes_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	# Resolves the tile’s segment index (returns [] if unknown)
	var tile_segment_index := get_segment_index(tile.coordinates)
	if tile_segment_index < 0:
		return []

	var result: Array[Rune] = []
	var segments := build_segments()
	# Walks every other segment in trigger order
	for segment_index in range(segments.size()):
		if segment_index == tile_segment_index:
			continue
		# Collects placed runes from each, applying filter_type when provided
		for coords: Vector2i in segments[segment_index]:
			var rune := _get_rune_on_coords(coords, filter_type)
			if rune != null:
				result.append(rune)
	return result


## First or last matching rune in a segment relative to tile's segment.
## segment_index_offset is added to the tile's segment index (0 = same segment, -1 = previous, +1 = next).
## pick_first_in_segment: true = first placed rune in segment, false = last placed rune in segment.
func get_rune_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> Rune:
	var segment_index := get_segment_index(tile.coordinates) + segment_index_offset
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return null

	var segment: Array = segments[segment_index]
	if pick_first_in_segment:
		for coords: Vector2i in segment:
			var rune := _get_rune_on_coords(coords, filter_type)
			if rune != null:
				return rune
	else:
		for i in range(segment.size() - 1, -1, -1):
			var rune := _get_rune_on_coords(segment[i], filter_type)
			if rune != null:
				return rune
	return null


# Clears per-segment turn totals so the next resolution starts from zero.
func reset_turn_results() -> void:
	var segment_count := build_segments().size()
	_segment_turn_scores.resize(segment_count)
	_segment_turn_multiplier.resize(segment_count)
	_segment_turn_gold.resize(segment_count)
	for i in segment_count:
		_segment_turn_scores[i] = 0
		_segment_turn_multiplier[i] = 0
		_segment_turn_gold[i] = 0


# Adds score produced by a rune on the given segment index.
func add_segment_turn_score(segment_index: int, amount: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_scores.size():
		return
	_segment_turn_scores[segment_index] += amount


func add_segment_turn_multiplier(segment_index: int, amount: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_multiplier.size():
		return
	_segment_turn_multiplier[segment_index] += amount

## Adds gold produced by a rune on the given segment index.
func add_segment_turn_gold(segment_index: int, amount: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_gold.size():
		return
	_segment_turn_gold[segment_index] += amount


func get_segment_turn_score(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_scores.size():
		return 0
	return _segment_turn_scores[segment_index]

func get_segment_turn_multiplier(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_multiplier.size():
		return 0
	return _segment_turn_multiplier[segment_index]

func get_segment_turn_gold(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_gold.size():
		return 0
	return _segment_turn_gold[segment_index]


## Clears cached segment groups so the next build_segments() call rebuilds them.
func _invalidate_segments_cache() -> void:
	_segments_cache_valid = false
	_segments_cache.clear()


## Breadth-first fill of ring distance from the map center tile.
func _compute_ring_distances() -> void:
	var queue: Array[Vector2i] = [_hex_center]
	_ring_distances[_hex_center] = 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var distance: int = _ring_distances[current]
		for direction in NEIGHBORS:
			var neighbor: Vector2i = _map.base_layer.get_neighbor_cell(current, direction)
			if not _map.map_data.has(neighbor) or _ring_distances.has(neighbor):
				continue
			_ring_distances[neighbor] = distance + 1
			queue.append(neighbor)


## All map coordinates whose ring distance equals ring.
func _get_tiles_in_ring(ring: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for coords: Vector2i in _map.map_data.keys():
		if _ring_distances.get(coords, -1) == ring:
			tiles.append(coords)
	return tiles


## Screen-space pixel position for a map coordinate (used for sorting and segments).
func _get_screen_position(coords: Vector2i) -> Vector2:
	return _map.base_layer.map_to_local(coords)


## Top-left tile in screen space from a set of coordinates.
func _find_top_left_tile(cells: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = cells[0]
	for cell: Vector2i in cells:
		var pos: Vector2 = _get_screen_position(cell)
		var best_pos: Vector2 = _get_screen_position(best)
		if pos.y < best_pos.y or (is_equal_approx(pos.y, best_pos.y) and pos.x < best_pos.x):
			best = cell
	return best


## Tile closest to the northeast direction from the map center (spiral start tile).
func _find_ne_start_tile(cells: Array[Vector2i]) -> Vector2i:
	var center_pos: Vector2 = _get_screen_position(_hex_center)
	const NE_ANGLE := -PI / 3.0
	var best: Vector2i = cells[0]
	var best_diff: float = INF
	for cell: Vector2i in cells:
		var pos: Vector2 = _get_screen_position(cell)
		var angle: float = atan2(pos.y - center_pos.y, pos.x - center_pos.x)
		var diff: float = absf(fmod(angle - NE_ANGLE + PI, TAU) - PI)
		if diff < best_diff:
			best_diff = diff
			best = cell
	return best


## Sorts ring tiles clockwise starting from start_tile around the map center.
func _sort_ring_clockwise(cells: Array[Vector2i], start_tile: Vector2i) -> Array[Vector2i]:
	var sorted_cells: Array[Vector2i] = cells.duplicate()
	var center_pos: Vector2 = _get_screen_position(_hex_center)
	var start_pos: Vector2 = _get_screen_position(start_tile)
	var start_angle: float = atan2(start_pos.y - center_pos.y, start_pos.x - center_pos.x)

	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = _get_screen_position(a)
		var pos_b: Vector2 = _get_screen_position(b)
		var angle_a: float = atan2(pos_a.y - center_pos.y, pos_a.x - center_pos.x)
		var angle_b: float = atan2(pos_b.y - center_pos.y, pos_b.x - center_pos.x)
		var order_a: float = fmod(angle_a - start_angle + TAU, TAU)
		var order_b: float = fmod(angle_b - start_angle + TAU, TAU)
		return order_a < order_b
	)
	return sorted_cells


## Trigger order: top-to-bottom rows, zigzagging left/right within each row.
## Even rows (0-based) go left → right; odd rows go right → left.
func _get_order_top_left_to_bottom_right() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	coords.assign(_map.map_data.keys())
	# First pass: stable top-to-bottom, left-to-right so rows are contiguous.
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = _get_screen_position(a)
		var pos_b: Vector2 = _get_screen_position(b)
		if not is_equal_approx(pos_a.y, pos_b.y):
			return pos_a.y < pos_b.y
		return pos_a.x < pos_b.x
	)

	# Reverse every other row so traversal zigzags across the map.
	var ordered: Array[Vector2i] = []
	var row_start: int = 0
	var row_index: int = 0
	while row_start < coords.size():
		var row_y: float = _get_screen_position(coords[row_start]).y
		var row_end: int = row_start + 1
		while row_end < coords.size() and is_equal_approx(_get_screen_position(coords[row_end]).y, row_y):
			row_end += 1
		var row_slice: Array[Vector2i] = coords.slice(row_start, row_end)
		# Odd rows traverse right → left.
		if row_index % 2 == 1:
			row_slice.reverse()
		ordered.append_array(row_slice)
		row_start = row_end
		row_index += 1
	return ordered


## Trigger order: outer ring inward, each ring traversed clockwise.
func _get_order_outer_to_inner() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for ring in range(_map.hex_size, -1, -1):
		var ring_tiles: Array[Vector2i] = _get_tiles_in_ring(ring)
		if ring == 0:
			coords.append(_hex_center)
			continue
		var start_tile: Vector2i = _find_top_left_tile(ring_tiles)
		coords.append_array(_sort_ring_clockwise(ring_tiles, start_tile))
	return coords


## Trigger order: center outward, each ring traversed clockwise from the northeast.
func _get_order_clockwise_spiral() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for ring in range(_map.hex_size + 1):
		var ring_tiles: Array[Vector2i] = _get_tiles_in_ring(ring)
		if ring == 0:
			coords.append(_hex_center)
			continue
		var start_tile: Vector2i = _find_ne_start_tile(ring_tiles)
		coords.append_array(_sort_ring_clockwise(ring_tiles, start_tile))
	return coords


## Segment grouping key for the active character (row Y or ring index).
func _get_segment_key(coords: Vector2i) -> Variant:
	match GameManager.selected_character:
		PlayerCharacter.Type.SURVEYOR:
			return _get_screen_position(coords).y
		PlayerCharacter.Type.ENCIRCLER, PlayerCharacter.Type.SPIRALIST:
			return get_ring_distance(coords)
		_:
			return _get_screen_position(coords).y


## Compares segment keys, using approximate equality for float row positions.
func _segment_keys_equal(a: Variant, b: Variant) -> bool:
	if a is float and b is float:
		return is_equal_approx(a, b)
	return a == b


## Splits the map into contiguous groups that share the same segment key in trigger order.
func _build_segments_uncached() -> Array[Array]:
	var segments: Array[Array] = []
	var current_segment: Array[Vector2i] = []
	var current_key: Variant = null

	for coords: Vector2i in get_coords_in_trigger_order():
		var key: Variant = _get_segment_key(coords)
		if current_key != null and not _segment_keys_equal(key, current_key):
			segments.append(current_segment)
			current_segment = []
		current_key = key
		current_segment.append(coords)

	if not current_segment.is_empty():
		segments.append(current_segment)
	return segments


## Returns the rune on coords when present and matching filter_type (or any type when null).
func _get_rune_on_coords(coords: Vector2i, filter_type: Variant = null) -> Rune:
	var hex: Hex = _map.map_data.get(coords)
	if hex == null or hex.active_rune == null:
		return null
	if filter_type != null and hex.active_rune.type != filter_type:
		return null
	return hex.active_rune
