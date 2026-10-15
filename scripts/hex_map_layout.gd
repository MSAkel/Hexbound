class_name HexMapLayout
extends RefCounted

# Shared kitchen board helpers. Ring distances, fire order, and station grouping.
# Seated-card lookups live on HexBoardQuery. Hour piles live in the scoring region below.

# Shared kitchen board. Four stations of eight hexes, left-to-right fire order.
const BOARD_ROW_LENGTHS: Array[int] = [8, 8, 8, 8]
const BOARD_TILE_COUNT := 32
# The last seats of every station are Meal slots. Slot 0 is open, slot 1 unlocks with station level.
const MEAL_SLOTS_PER_STATION := 2
# Offset origin so every generated cell stays in non-negative tile coords.
const BOARD_ORIGIN := Vector2i(2, 0)

# Square grid, orthogonal adjacency only. Diagonals are not neighbors.
const NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
]

var _map: Node
var _hex_center: Vector2i = Vector2i.ZERO
var _ring_distances: Dictionary = {}
var _segments_cache: Array[Array] = []
var _segments_cache_valid: bool = false
# Fire order is stable until the map is regenerated. Cache it so lookups skip a full sort.
var _trigger_order_cache: Array[Vector2i] = []
var _trigger_order_cache_valid: bool = false
# Vector2i -> segment index, filled whenever segments are rebuilt.
var _segment_index_by_coords: Dictionary = {}
# Visual rows used by fire order, stations, and gamepad navigation. Rebuilt with segments.
var _spatial_rows_cache: Array = []
# Vector2i -> opposite board cell around the map center. Stable until regenerate.
var _opposite_by_coords: Dictionary = {}
# Per-segment Flavour and Gold produced during the current turn resolution.
var _segment_turn_flavours: Array[int] = []
var _segment_additive_mult: Array[float] = []
var _segment_multiplicative_mult: Array[float] = []
var _segment_turn_gold: Array[int] = []
# Hour-wide scoring piles. Rating is Flavour x Additive. xMult folds into Additive immediately.
var _hour_flavour: int = 0
var _hour_additive_mult: float = 1.0
# Completed tile card activations on each segment during the current turn.
var _segment_turn_triggers: Array[int] = []
# True after a segment's natural trigger pass has finished this turn.
var _segment_resolved: Array[bool] = []
# True when another segment relayed Energy or Mult into this one this turn.
var _segment_received_relay: Array[bool] = []
# Cards that actually broke on each segment this turn.
var _segment_breaks: Array[int] = []


## Binds this layout helper to a live map instance.
func setup(map: Node) -> void:
	_map = map


## Walks square grid neighbors to build the shared 8-wide block. Rows stack straight down.
static func compute_board_cells(base_layer: TileMapLayer, origin: Vector2i = BOARD_ORIGIN) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var row_start := origin
	for row_i in BOARD_ROW_LENGTHS.size():
		var length: int = BOARD_ROW_LENGTHS[row_i]
		var cell := row_start
		for col in length:
			cells.append(cell)
			if col < length - 1:
				cell = base_layer.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_RIGHT_SIDE)
		row_start = base_layer.get_neighbor_cell(row_start, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE)
	return cells


## Center seat used for ring math and gamepad default focus.
static func board_hex_center(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return BOARD_ORIGIN
	# Middle of the middle row.
	var middle_row := BOARD_ROW_LENGTHS.size() / 2
	var center_index := 0
	for row_i in middle_row:
		center_index += BOARD_ROW_LENGTHS[row_i]
	center_index += (BOARD_ROW_LENGTHS[middle_row] - 1) / 2
	center_index = mini(center_index, cells.size() - 1)
	return cells[center_index]


## Rebuilds ring distances, opposite seats, and clears the segment cache after terrain generation.
func reset(hex_center: Vector2i) -> void:
	_hex_center = hex_center
	_ring_distances.clear()
	_opposite_by_coords.clear()
	_invalidate_segments_cache()
	_compute_ring_distances()
	_compute_opposites()


## Map center tile used as the origin for ring distance calculations.
func get_hex_center() -> Vector2i:
	return _hex_center


## Tile 180 degrees from coords around the map center. Returns coords when the map is empty.
func get_opposite_coords(coords: Vector2i) -> Vector2i:
	return _opposite_by_coords.get(coords, coords)


## Ring index from the map center (0 = center).
func get_ring_distance(coords: Vector2i) -> int:
	return _ring_distances.get(coords, -1)


## All map coordinates in fire order. Top-to-bottom rows, left to right within each row.
func get_coords_in_trigger_order() -> Array[Vector2i]:
	if _trigger_order_cache_valid and _trigger_order_cache_matches_map():
		return _trigger_order_cache

	var ordered: Array[Vector2i] = []
	for row: Array in build_segments():
		ordered.append_array(row)
	_trigger_order_cache = ordered
	_trigger_order_cache_valid = true
	return _trigger_order_cache


## Drops cached trigger order and segment groups. Call when map_data keys change.
func invalidate_caches() -> void:
	_ring_distances.clear()
	_invalidate_segments_cache()


## Station (row) index for coords, or -1 when the tile is not on the board.
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


## Meal slot index (0 or 1) for coords, or -1 when the seat is a regular tile.
func get_meal_slot_index(coords: Vector2i) -> int:
	var segment_index := get_segment_index(coords)
	if segment_index < 0:
		return -1
	var segment: Array = build_segments()[segment_index]
	var first_meal := segment.size() - MEAL_SLOTS_PER_STATION
	var index := segment.find(coords)
	if index < first_meal:
		return -1
	return index - first_meal


## True when coords is one of the Meal-only seats at the end of its station.
func is_meal_slot(coords: Vector2i) -> bool:
	return get_meal_slot_index(coords) >= 0


## Meal slot coordinates of a station, in fire order.
func get_meal_slot_coords(segment_index: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	var segments := build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return coords
	var segment: Array = segments[segment_index]
	for i in range(maxi(segment.size() - MEAL_SLOTS_PER_STATION, 0), segment.size()):
		coords.append(segment[i])
	return coords


## Station groups. Each station is an ordered list of coordinates.
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


#region --- Hour scoring ledger ---
# Clears per-segment turn totals so the next resolution starts from zero.
func reset_turn_results() -> void:
	var segment_count := build_segments().size()
	_segment_turn_flavours.resize(segment_count)
	_segment_additive_mult.resize(segment_count)
	_segment_multiplicative_mult.resize(segment_count)
	_segment_turn_gold.resize(segment_count)
	_segment_turn_triggers.resize(segment_count)
	_segment_resolved.resize(segment_count)
	_segment_received_relay.resize(segment_count)
	_segment_breaks.resize(segment_count)
	_hour_flavour = 0
	_hour_additive_mult = 1.0
	for i in segment_count:
		_segment_turn_flavours[i] = 0
		# Base additive mult is 1 so Flavour is unchanged when no mult cards fire in a segment.
		_segment_additive_mult[i] = 1.0
		# Base multiplicative mult is 1 so empty segments keep Flavour unchanged.
		_segment_multiplicative_mult[i] = 1.0
		_segment_turn_gold[i] = 0
		_segment_turn_triggers[i] = 0
		_segment_resolved[i] = false
		_segment_received_relay[i] = false
		_segment_breaks[i] = 0


# Adds Flavour produced by a card on the given segment index.
func add_segment_turn_flavour(segment_index: int, amount: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_flavours.size():
		return
	_segment_turn_flavours[segment_index] += amount
	_hour_flavour += amount


func add_segment_additive_mult(segment_index: int, amount: float) -> void:
	if segment_index < 0 or segment_index >= _segment_additive_mult.size():
		return
	_segment_additive_mult[segment_index] += amount
	_hour_additive_mult += amount


func multiply_segment_multiplicative_mult(segment_index: int, factor: float) -> void:
	if segment_index < 0 or segment_index >= _segment_multiplicative_mult.size():
		return
	if is_zero_approx(factor):
		return
	_segment_multiplicative_mult[segment_index] *= factor
	# xMult immediately folds into the shared Additive pile used for hour Rating.
	_hour_additive_mult *= factor

## Adds gold produced by a rune on the given segment index.
func add_segment_turn_gold(segment_index: int, amount: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_gold.size():
		return
	_segment_turn_gold[segment_index] += amount


func get_segment_turn_flavour(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_flavours.size():
		return 0
	return _segment_turn_flavours[segment_index]

func get_segment_additive_mult(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= _segment_additive_mult.size():
		return 1.0
	return _segment_additive_mult[segment_index]


func get_segment_multiplicative_mult(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= _segment_multiplicative_mult.size():
		return 1.0
	return _segment_multiplicative_mult[segment_index]

func get_segment_turn_gold(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_gold.size():
		return 0
	return _segment_turn_gold[segment_index]


func get_hour_flavour() -> int:
	return _hour_flavour


func get_hour_additive_mult() -> float:
	return _hour_additive_mult


func get_hour_gold() -> int:
	var total := 0
	for amount: int in _segment_turn_gold:
		total += amount
	return total


# Counts one completed activation on the given segment this turn.
func add_segment_turn_trigger(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _segment_turn_triggers.size():
		return
	_segment_turn_triggers[segment_index] += 1


func get_segment_turn_trigger_count(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_turn_triggers.size():
		return 0
	return _segment_turn_triggers[segment_index]


## Returns true the first time this segment is closed this turn.
func mark_segment_resolved(segment_index: int) -> bool:
	if segment_index < 0 or segment_index >= _segment_resolved.size():
		return false
	if _segment_resolved[segment_index]:
		return false
	_segment_resolved[segment_index] = true
	return true


func is_segment_resolved(segment_index: int) -> bool:
	if segment_index < 0 or segment_index >= _segment_resolved.size():
		return false
	return _segment_resolved[segment_index]


func mark_segment_received_relay(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _segment_received_relay.size():
		return
	_segment_received_relay[segment_index] = true


func count_segments_that_received_relay() -> int:
	var count := 0
	for received: bool in _segment_received_relay:
		if received:
			count += 1
	return count


func add_segment_break(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _segment_breaks.size():
		return
	_segment_breaks[segment_index] += 1


func get_segment_breaks(segment_index: int) -> int:
	if segment_index < 0 or segment_index >= _segment_breaks.size():
		return 0
	return _segment_breaks[segment_index]


func capture_turn_results() -> Dictionary:
	return {
		"flavours": _segment_turn_flavours.duplicate(),
		"additive_mults": _segment_additive_mult.duplicate(),
		"multiplicative_mults": _segment_multiplicative_mult.duplicate(),
		"gold": _segment_turn_gold.duplicate(),
		"triggers": _segment_turn_triggers.duplicate(),
		"hour_flavour": _hour_flavour,
		"hour_additive_mult": _hour_additive_mult,
	}


func apply_turn_results(state: Dictionary) -> void:
	# "scores" keeps turn snapshots from older saves loadable after the terminology rename.
	var flavours: Array = state.get("flavours", state.get("scores", []))
	var additive_mults: Array = state.get("additive_mults", state.get("multipliers", []))
	var multiplicative_mults: Array = state.get("multiplicative_mults", [])
	var gold_amounts: Array = state.get("gold", [])
	var triggers: Array = state.get("triggers", [])
	var segment_count := build_segments().size()

	_segment_turn_flavours.resize(segment_count)
	_segment_additive_mult.resize(segment_count)
	_segment_multiplicative_mult.resize(segment_count)
	_segment_turn_gold.resize(segment_count)
	_segment_turn_triggers.resize(segment_count)

	for i in segment_count:
		_segment_turn_flavours[i] = int(flavours[i]) if i < flavours.size() else 0
		_segment_additive_mult[i] = float(additive_mults[i]) if i < additive_mults.size() else 1.0
		_segment_multiplicative_mult[i] = float(multiplicative_mults[i]) if i < multiplicative_mults.size() else 1.0
		_segment_turn_gold[i] = int(gold_amounts[i]) if i < gold_amounts.size() else 0
		_segment_turn_triggers[i] = int(triggers[i]) if i < triggers.size() else 0
	_hour_flavour = int(state.get("hour_flavour", _sum_int_array(_segment_turn_flavours)))
	_hour_additive_mult = float(state.get("hour_additive_mult", 1.0))
	if not state.has("hour_additive_mult"):
		# Older saves stored xMult separately. Reconstruct the folded Additive as well as we can.
		_hour_additive_mult = 1.0
		for i in segment_count:
			_hour_additive_mult += maxf(_segment_additive_mult[i] - 1.0, 0.0)
			_hour_additive_mult *= _segment_multiplicative_mult[i]


#endregion --- Hour scoring ledger ---


func _sum_int_array(values: Array[int]) -> int:
	var total := 0
	for value: int in values:
		total += value
	return total


## Clears cached segment groups so the next build_segments() call rebuilds them.
func _invalidate_segments_cache() -> void:
	_segments_cache_valid = false
	_segments_cache.clear()
	_segment_index_by_coords.clear()
	_spatial_rows_cache.clear()
	_trigger_order_cache_valid = false
	_trigger_order_cache.clear()


## True when the trigger-order cache still matches every live map_data key.
func _trigger_order_cache_matches_map() -> bool:
	if _trigger_order_cache.size() != _map.map_data.size():
		return false
	for coords: Vector2i in _trigger_order_cache:
		if not _map.map_data.has(coords):
			return false
	return true


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


## Screen-space pixel position for a map coordinate (used for sorting and segments).
func _get_screen_position(coords: Vector2i) -> Vector2:
	return _map.base_layer.map_to_local(coords)


## Groups map tiles into visual rows (top-to-bottom, left-to-right within each row).
func get_spatial_rows() -> Array:
	build_segments()
	return _spatial_rows_cache


## Stations are the visual rows. Fire order already walks each row left to right.
func _build_segments_uncached() -> Array[Array]:
	_spatial_rows_cache = _compute_spatial_rows()
	var segments: Array[Array] = []
	for row: Array in _spatial_rows_cache:
		var segment: Array[Vector2i] = []
		segment.assign(row)
		segments.append(segment)
	return segments


## Groups map tiles into visual rows (top-to-bottom, left-to-right within each row).
func _compute_spatial_rows() -> Array:
	var coords: Array[Vector2i] = []
	coords.assign(_map.map_data.keys())
	var positions: Dictionary = {}
	for cell: Vector2i in coords:
		positions[cell] = _get_screen_position(cell)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = positions[a]
		var pos_b: Vector2 = positions[b]
		if not is_equal_approx(pos_a.y, pos_b.y):
			return pos_a.y < pos_b.y
		return pos_a.x < pos_b.x
	)

	var rows: Array = []
	var row_start: int = 0
	while row_start < coords.size():
		var row_y: float = positions[coords[row_start]].y
		var row_end: int = row_start + 1
		while row_end < coords.size() and is_equal_approx(positions[coords[row_end]].y, row_y):
			row_end += 1
		rows.append(coords.slice(row_start, row_end))
		row_start = row_end
	return rows


## Caches the seat 180 degrees from each cell around the map center.
func _compute_opposites() -> void:
	_opposite_by_coords.clear()
	if _map == null or _map.map_data.is_empty():
		return
	var positions: Dictionary = {}
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for map_coords: Vector2i in _map.map_data.keys():
		var pos := _get_screen_position(map_coords)
		positions[map_coords] = pos
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	# Reflect through the middle of the board, not a seat. An even-sized board has no center seat,
	# so reflecting through one would land past the far edge and snap to the wrong neighbor.
	var center_pos := (min_pos + max_pos) * 0.5
	for coords: Vector2i in _map.map_data.keys():
		var reflected_pos: Vector2 = center_pos * 2.0 - positions[coords]
		var best: Vector2i = coords
		var best_dist := INF
		for map_coords: Vector2i in _map.map_data.keys():
			var dist := reflected_pos.distance_squared_to(positions[map_coords])
			if dist < best_dist:
				best_dist = dist
				best = map_coords
		_opposite_by_coords[coords] = best
