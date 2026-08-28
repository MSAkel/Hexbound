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

var _map: Node
var _hex_center: Vector2i = Vector2i.ZERO
var _ring_distances: Dictionary = {}
var _segments_cache: Array[Array] = []
var _segments_cache_valid: bool = false
# Trigger order is stable until the map is regenerated. Cache it so NUMBERED_GRID
# lookups do not rebuild and sort the whole grid on every call.
var _trigger_order_cache: Array[Vector2i] = []
var _trigger_order_cache_valid: bool = false
# Vector2i -> segment index, filled whenever segments are rebuilt.
var _segment_index_by_coords: Dictionary = {}
# Per-segment score and gold produced during the current turn resolution.
var _segment_turn_scores: Array[int] = []
var _segment_turn_multiplier: Array[int] = []
var _segment_turn_gold: Array[int] = []
# Completed tile card activations on each segment during the current turn.
var _segment_turn_triggers: Array[int] = []


## Binds this layout helper to a live map instance.
func setup(map: Node) -> void:
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


## Tile 180 degrees from coords around the map center. Returns coords when the map is empty.
func get_opposite_coords(coords: Vector2i) -> Vector2i:
	if _map == null or _map.map_data.is_empty():
		return coords
	var center_pos: Vector2 = _get_screen_position(_hex_center)
	var reflected_pos: Vector2 = center_pos * 2.0 - _get_screen_position(coords)
	var best: Vector2i = coords
	var best_dist := INF
	for map_coords: Vector2i in _map.map_data.keys():
		var dist := reflected_pos.distance_squared_to(_get_screen_position(map_coords))
		if dist < best_dist:
			best_dist = dist
			best = map_coords
	return best


## Ring index from the map center (0 = center, outer ring = map hex_size).
func get_ring_distance(coords: Vector2i) -> int:
	return _ring_distances.get(coords, -1)


## All map coordinates sorted by the active character trigger-order rule.
func get_coords_in_trigger_order() -> Array[Vector2i]:
	if _trigger_order_cache_valid:
		return _trigger_order_cache

	_trigger_order_cache = _compute_trigger_order()
	_trigger_order_cache_valid = true
	return _trigger_order_cache


## All map hex tiles in the same order as get_coords_in_trigger_order().
func get_hexes_in_trigger_order() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for coords: Vector2i in get_coords_in_trigger_order():
		hexes.append(_map.map_data[coords])
	return hexes


## Segment index for coords under the active character's row/ring grouping (-1 when unknown).
func get_segment_index(coords: Vector2i) -> int:
	# Ensures the coords lookup is populated. Segment grouping is stable until reset().
	build_segments()
	return int(_segment_index_by_coords.get(coords, -1))


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


## Tile count for a segment index, or 0 when the index is invalid.
func get_segment_size(segment_index: int) -> int:
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return 0
	return segments[segment_index].size()


## Character-specific segment groups (each segment is an ordered list of coordinates).
func build_segments() -> Array[Array]:
	if _segments_cache_valid:
		return _segments_cache

	_segments_cache = _build_segments_uncached()
	_segment_index_by_coords.clear()
	for segment_index in range(_segments_cache.size()):
		for coords: Vector2i in _segments_cache[segment_index]:
			_segment_index_by_coords[coords] = segment_index
	_segments_cache_valid = true
	return _segments_cache


## All placed runes on one segment, optionally filtered by rune type.
func get_all_tile_cards_on_segment(segment_index: int, filter_type: Variant = null) -> Array[TileCard]:
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return []

	var result: Array[TileCard] = []
	for coords: Vector2i in segments[segment_index]:
		var rune := _get_rune_on_coords(coords, filter_type)
		if rune != null:
			result.append(rune)
	return result


## All placed runes on other segments, optionally filtered by rune type.
func get_all_tile_cards_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	# Resolves the tile’s segment index (returns [] if unknown)
	var tile_segment_index := get_segment_index(tile.coordinates)
	if tile_segment_index < 0:
		return []

	var result: Array[TileCard] = []
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
func get_tile_card_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> TileCard:
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
	_segment_turn_triggers.resize(segment_count)
	for i in segment_count:
		_segment_turn_scores[i] = 0
		# Base multiplier is 1 so score is unchanged when no mult runes fire in a segment.
		_segment_turn_multiplier[i] = 1
		_segment_turn_gold[i] = 0
		_segment_turn_triggers[i] = 0


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


# Counts one completed activation on the given segment this turn.
func add_segment_turn_trigger(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_triggers.size():
		return
	_segment_turn_triggers[segment_index] += 1


func get_segment_turn_trigger_count(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_triggers.size():
		return 0
	return _segment_turn_triggers[segment_index]


func capture_turn_results() -> Dictionary:
	return {
		"scores": _segment_turn_scores.duplicate(),
		"multipliers": _segment_turn_multiplier.duplicate(),
		"gold": _segment_turn_gold.duplicate(),
		"triggers": _segment_turn_triggers.duplicate(),
	}


func apply_turn_results(state: Dictionary) -> void:
	var scores: Array = state.get("scores", [])
	var multipliers: Array = state.get("multipliers", [])
	var gold_amounts: Array = state.get("gold", [])
	var triggers: Array = state.get("triggers", [])
	var segment_count := build_segments().size()

	_segment_turn_scores.resize(segment_count)
	_segment_turn_multiplier.resize(segment_count)
	_segment_turn_gold.resize(segment_count)
	_segment_turn_triggers.resize(segment_count)

	for i in segment_count:
		_segment_turn_scores[i] = int(scores[i]) if i < scores.size() else 0
		_segment_turn_multiplier[i] = int(multipliers[i]) if i < multipliers.size() else 1
		_segment_turn_gold[i] = int(gold_amounts[i]) if i < gold_amounts.size() else 0
		_segment_turn_triggers[i] = int(triggers[i]) if i < triggers.size() else 0


## Clears cached segment groups so the next build_segments() call rebuilds them.
func _invalidate_segments_cache() -> void:
	_segments_cache_valid = false
	_segments_cache.clear()
	_segment_index_by_coords.clear()
	_trigger_order_cache_valid = false
	_trigger_order_cache.clear()


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
	var ordered: Array[Vector2i] = []
	var row_index := 0
	for row: Array in _get_spatial_rows():
		var row_slice: Array = row.duplicate()
		# Odd rows traverse right → left.
		if row_index % 2 == 1:
			row_slice.reverse()
		ordered.append_array(row_slice)
		row_index += 1
	return ordered


## Trigger order: ring-by-ring traversal, optionally from the outside in.
func _get_order_by_rings(from_outer: bool, use_ne_start: bool) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	var ring: int = _map.hex_size if from_outer else 0
	var end: int = -1 if from_outer else _map.hex_size + 1
	var step := -1 if from_outer else 1

	while ring != end:
		if ring == 0:
			coords.append(_hex_center)
		else:
			var ring_tiles: Array[Vector2i] = _get_tiles_in_ring(ring)
			var start_tile: Vector2i = (
				_find_ne_start_tile(ring_tiles) if use_ne_start
				else _find_top_left_tile(ring_tiles)
			)
			coords.append_array(_sort_ring_clockwise(ring_tiles, start_tile))
		ring += step
	return coords


## Groups map tiles into visual rows (top-to-bottom, left-to-right within each row).
func _get_spatial_rows() -> Array:
	var coords: Array[Vector2i] = []
	coords.assign(_map.map_data.keys())
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = _get_screen_position(a)
		var pos_b: Vector2 = _get_screen_position(b)
		if not is_equal_approx(pos_a.y, pos_b.y):
			return pos_a.y < pos_b.y
		return pos_a.x < pos_b.x
	)

	var rows: Array = []
	var row_start: int = 0
	while row_start < coords.size():
		var row_y: float = _get_screen_position(coords[row_start]).y
		var row_end: int = row_start + 1
		while row_end < coords.size() and is_equal_approx(_get_screen_position(coords[row_end]).y, row_y):
			row_end += 1
		rows.append(coords.slice(row_start, row_end))
		row_start = row_end
	return rows


## Maps a numbered preview grid onto live map coordinates to produce trigger order.
func _get_order_from_numbered_grid(order_grid: Array) -> Array[Vector2i]:
	var rows := _get_spatial_rows()
	if rows.size() != order_grid.size():
		push_warning("Trigger-order grid row count does not match the map layout.")
		return _get_order_top_left_to_bottom_right()

	var order_to_coords: Dictionary = {}
	for row_idx in range(rows.size()):
		var row_coords: Array = rows[row_idx]
		var row_orders: Array = order_grid[row_idx]
		if row_coords.size() != row_orders.size():
			push_warning("Trigger-order grid column count mismatch at row %d." % row_idx)
			return _get_order_top_left_to_bottom_right()
		for col_idx in range(row_coords.size()):
			order_to_coords[row_orders[col_idx]] = row_coords[col_idx]

	var ordered: Array[Vector2i] = []
	for order in range(1, _map.map_data.size() + 1):
		if not order_to_coords.has(order):
			push_warning("Trigger-order grid is missing index %d." % order)
			return _get_order_top_left_to_bottom_right()
		ordered.append(order_to_coords[order])
	return ordered


## Trigger order for the active character, computed once per map generation.
func _compute_trigger_order() -> Array[Vector2i]:
	var character := GameManager.selected_character
	if character == null:
		return _get_order_top_left_to_bottom_right()

	match character.trigger_order_strategy:
		CharacterDefinition.TriggerOrderStrategy.ZIGZAG_ROWS:
			return _get_order_top_left_to_bottom_right()
		CharacterDefinition.TriggerOrderStrategy.RINGS_OUTWARD:
			return _get_order_by_rings(true, false)
		CharacterDefinition.TriggerOrderStrategy.RINGS_INWARD:
			return _get_order_by_rings(false, true)
		CharacterDefinition.TriggerOrderStrategy.NUMBERED_GRID:
			return _get_order_from_numbered_grid(character.numbered_order_grid)
		_:
			return _get_order_top_left_to_bottom_right()


## Segment index for custom layouts where yellow preview tiles start a new segment.
func _get_layout_segment_index(coords: Vector2i, segment_starts: Array[int]) -> int:
	# Uses the cached trigger-order list. Do not rebuild the numbered grid per tile.
	var order: int = get_coords_in_trigger_order().find(coords) + 1
	if order <= 0:
		return 0

	var segment_idx := 0
	for i in range(segment_starts.size()):
		if order >= segment_starts[i]:
			segment_idx = i
	return segment_idx


## Segment grouping key for the active character (row Y, ring index, or layout segment).
func _get_segment_key(coords: Vector2i) -> Variant:
	var character := GameManager.selected_character
	if character == null:
		return _get_screen_position(coords).y

	match character.segment_key_strategy:
		CharacterDefinition.SegmentKeyStrategy.ROW_Y:
			return _get_screen_position(coords).y
		CharacterDefinition.SegmentKeyStrategy.RING:
			return get_ring_distance(coords)
		CharacterDefinition.SegmentKeyStrategy.NUMBERED_GRID:
			return _get_layout_segment_index(coords, character.segment_starts)
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


## Returns the rune on coords when present, triggerable, and matching filter_type.
func _get_rune_on_coords(coords: Vector2i, filter_type: Variant = null) -> TileCard:
	var hex: Hex = _map.map_data.get(coords)
	if hex == null or hex.active_tile_card == null:
		return null
	if not _map.is_tile_card_triggerable(hex):
		return null
	if filter_type != null and hex.active_tile_card.type != filter_type:
		return null
	return hex.active_tile_card
