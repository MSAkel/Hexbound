class_name HexBoardQuery
extends RefCounted

## Indexed lookups for seated cards, fire order, adjacency, and QueryScope.
## HexTileMap owns the live tiles. This object answers "which cards sit where" without
## walking the whole board on every card effect.

## How strictly a seated card must qualify before a query returns it.
enum SeatFilter {
	## Any occupant, including inactive cards.
	SEATED,
	## Occupant that can fire from its own fire-order slot.
	ACTIVE,
	## Occupant another card may queue or target this Hour.
	TRIGGERABLE,
}

var _map: HexTileMap
## TileCard instance to the hex currently seating it.
var _hex_by_card: Dictionary = {}
## Board cell to its fire-order index.
var _trigger_index_by_coords: Dictionary = {}
## Every live hex in fire order. Stable until the board is regenerated.
var _hexes_in_order: Array[Hex] = []
## Vector2i to the up-to-four orthogonal neighbor tiles that exist on this board.
var _neighbors_by_coords: Dictionary = {}
## Vector2i to true when at least one neighbor direction leaves the board.
var _edge_by_coords: Dictionary = {}
## Per-station hex lists in fire order, aligned with HexMapLayout.build_segments().
var _hexes_by_segment: Array = []
## Kitchenware statuses that depend on board position (Seasoned, Blended, Passed). Rebuilt by
## refresh_kitchenware_prep whenever a seat changes. Station index to Ingredients passed down into it.
var _passed_into_segment: Dictionary = {}
## Cards currently holding lent kinds or statuses, so the next refresh can clear them.
var _prepped_cards: Array[TileCard] = []
var _refreshing_prep := false


func setup(map: HexTileMap) -> void:
	_map = map


## Drops every cache. Call when map_data itself is being thrown away.
func clear() -> void:
	_clear_kitchenware_prep()
	_hex_by_card.clear()
	_trigger_index_by_coords.clear()
	_hexes_in_order.clear()
	_neighbors_by_coords.clear()
	_edge_by_coords.clear()
	_hexes_by_segment.clear()


## Rebuilds fire-order, adjacency, and occupancy from the current map_data.
func rebuild_spatial_index() -> void:
	clear()
	if _map == null:
		return

	for coords: Vector2i in _map.get_coords_in_trigger_order():
		var hex: Hex = _map.map_data.get(coords)
		if hex == null:
			continue
		_trigger_index_by_coords[coords] = _hexes_in_order.size()
		_hexes_in_order.append(hex)
		_cache_neighbors(hex)

	for segment: Array in _map.build_segments():
		var hexes: Array[Hex] = []
		for coords: Vector2i in segment:
			var hex: Hex = _map.map_data.get(coords)
			if hex != null:
				hexes.append(hex)
		_hexes_by_segment.append(hexes)

	_rebuild_occupancy_from_map()


## Keeps the card-to-hex index in sync when a seat is filled or cleared.
func set_occupancy(hex: Hex, previous: TileCard, current: TileCard) -> void:
	if previous != null:
		_hex_by_card.erase(previous)
	if current != null and hex != null:
		_hex_by_card[current] = hex
	refresh_kitchenware_prep()


func get_hex_for_card(card: TileCard) -> Hex:
	if card == null:
		return null
	var hex: Hex = _hex_by_card.get(card)
	if hex != null and hex.active_tile_card == card:
		return hex
	_rebuild_occupancy_from_map()
	hex = _hex_by_card.get(card)
	if hex != null and hex.active_tile_card == card:
		return hex
	return null


func trigger_index(hex: Hex) -> int:
	if hex == null:
		return -1
	return int(_trigger_index_by_coords.get(hex.coordinates, -1))


func hexes_in_trigger_order() -> Array[Hex]:
	var hexes: Array[Hex] = []
	hexes.assign(_hexes_in_order)
	return hexes


func adjacent_hexes(coords: Vector2i) -> Array[Hex]:
	var stored: Variant = _neighbors_by_coords.get(coords)
	if stored is Array:
		var hexes: Array[Hex] = []
		hexes.assign(stored)
		return hexes
	var empty: Array[Hex] = []
	return empty


func is_edge_tile(coords: Vector2i) -> bool:
	return bool(_edge_by_coords.get(coords, false))


func hexes_in_segment(segment_index: int) -> Array[Hex]:
	if segment_index < 0 or segment_index >= _hexes_by_segment.size():
		var empty: Array[Hex] = []
		return empty
	var hexes: Array[Hex] = []
	hexes.assign(_hexes_by_segment[segment_index])
	return hexes


## Occupied hexes in dictionary order. Use hexes_in_trigger_order when order matters.
func occupied_hexes() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in _hex_by_card.values():
		if hex != null:
			hexes.append(hex)
	return hexes


func card_on_hex(
	hex: Hex,
	filter_type: Variant = null,
	seat_filter: SeatFilter = SeatFilter.TRIGGERABLE
) -> TileCard:
	if hex == null or hex.active_tile_card == null:
		return null
	match seat_filter:
		SeatFilter.ACTIVE:
			if not _map.is_tile_card_active(hex):
				return null
		SeatFilter.TRIGGERABLE:
			if not _map.is_tile_card_triggerable(hex):
				return null
		_:
			pass
	if filter_type != null and not TileCard.matches_type_filter(hex.active_tile_card.type, filter_type):
		return null
	return hex.active_tile_card


func cards_from_hexes(
	hexes: Array,
	filter_type: Variant = null,
	seat_filter: SeatFilter = SeatFilter.TRIGGERABLE
) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for hex: Hex in hexes:
		var card := card_on_hex(hex, filter_type, seat_filter)
		if card != null:
			result.append(card)
	return result


func placed_cards(filter_type: Variant = null) -> Array[TileCard]:
	return cards_from_hexes(_hexes_in_order, filter_type)


func adjacent_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	if tile == null:
		return []
	return cards_from_hexes(adjacent_hexes(tile.coordinates), filter_type)


## Adjacent hexes that fire after tile, earliest-first.
func following_adjacent_hexes(tile: Hex) -> Array[Hex]:
	var result: Array[Hex] = []
	var self_index := trigger_index(tile)
	if self_index < 0:
		return result
	for hex: Hex in adjacent_hexes(tile.coordinates):
		if trigger_index(hex) > self_index:
			result.append(hex)
	result.sort_custom(func(a: Hex, b: Hex) -> bool:
		return trigger_index(a) < trigger_index(b)
	)
	return result


func following_adjacent_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return cards_from_hexes(following_adjacent_hexes(tile), filter_type)


func cards_on_segment(segment_index: int, filter_type: Variant = null) -> Array[TileCard]:
	return cards_from_hexes(hexes_in_segment(segment_index), filter_type)


func cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	if tile == null or _map == null:
		return []
	return cards_on_segment(_map.get_segment_index(tile.coordinates), filter_type)


## Contiguous previous seats, including empties. Gaps are not skipped.
func immediately_previous_hexes(tile: Hex, count: int) -> Array[Hex]:
	var result: Array[Hex] = []
	if tile == null or count <= 0:
		return result
	var self_index := trigger_index(tile)
	if self_index < 0:
		return result
	for i in range(1, count + 1):
		var prev_index := self_index - i
		if prev_index < 0:
			break
		result.append(_hexes_in_order[prev_index])
	return result


func cards_relative_to_trigger_order(
	tile: Hex,
	count: int,
	previous: bool,
	filter_type: Variant = null
) -> Array[TileCard]:
	var result: Array[TileCard] = []
	var current_index := trigger_index(tile)
	if current_index < 0 or count <= 0:
		return result

	var start := current_index - 1 if previous else current_index + 1
	var end := -1 if previous else _hexes_in_order.size()
	var step := -1 if previous else 1
	for i in range(start, end, step):
		# Fire-order walks use ACTIVE so Overdrive still occupies its own slot.
		var card := card_on_hex(_hexes_in_order[i], filter_type, SeatFilter.ACTIVE)
		if card == null:
			continue
		result.append(card)
		if result.size() >= count:
			break
	return result


func cards_in_scope(
	tile: Hex,
	scope: TileCard.QueryScope,
	filter_type: Variant = null
) -> Array[TileCard]:
	if tile == null or _map == null:
		return []
	match scope:
		TileCard.QueryScope.ADJACENT:
			return adjacent_cards(tile, filter_type)
		TileCard.QueryScope.FOLLOWING_ADJACENT:
			return following_adjacent_cards(tile, filter_type)
		TileCard.QueryScope.FOLLOWING_SAME_SEGMENT:
			return _cards_on_same_segment_as(following_adjacent_cards(tile, filter_type), tile)
		TileCard.QueryScope.SAME_SEGMENT:
			return cards_on_same_segment(tile, filter_type)
		TileCard.QueryScope.PLACED:
			return placed_cards(filter_type)
		_:
			return []


func cards_by_kind(
	tile: Hex,
	filter_kind: Variant,
	scope: TileCard.QueryScope
) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card: TileCard in cards_in_scope(tile, scope):
		if TileCard.matches_kind_filter(card, filter_kind):
			result.append(card)
	return result


func coords_for_cards(cards: Array[TileCard]) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for card: TileCard in cards:
		var hex := get_hex_for_card(card)
		if hex != null:
			coords.append(hex.coordinates)
	return coords


func _cards_on_same_segment_as(cards: Array[TileCard], tile: Hex) -> Array[TileCard]:
	if tile == null or _map == null:
		return []
	var segment_index := _map.get_segment_index(tile.coordinates)
	var result: Array[TileCard] = []
	for card: TileCard in cards:
		var hex := get_hex_for_card(card)
		if hex == null:
			continue
		if _map.get_segment_index(hex.coordinates) != segment_index:
			continue
		result.append(card)
	return result


func _cache_neighbors(hex: Hex) -> void:
	var neighbors: Array[Hex] = []
	var is_edge := false
	for direction in HexMapLayout.NEIGHBORS:
		var neighbor_coords: Vector2i = _map.base_layer.get_neighbor_cell(hex.coordinates, direction)
		if _map.map_data.has(neighbor_coords):
			neighbors.append(_map.map_data[neighbor_coords])
		else:
			is_edge = true
	_neighbors_by_coords[hex.coordinates] = neighbors
	_edge_by_coords[hex.coordinates] = is_edge


func _rebuild_occupancy_from_map() -> void:
	_hex_by_card.clear()
	if _map == null:
		return
	for hex: Hex in _map.map_data.values():
		if hex.active_tile_card != null:
			_hex_by_card[hex.active_tile_card] = hex
	refresh_kitchenware_prep()


#region --- Kitchenware statuses ---
## Re-applies every seated Kitchenware's board status (Seasoned, Blended, Passed) in fire order.
## These depend only on where cards sit, so recipes and chips see them before the Hour starts.
func refresh_kitchenware_prep() -> void:
	if _refreshing_prep or _map == null:
		return
	_refreshing_prep = true
	_clear_kitchenware_prep()
	for hex: Hex in _hexes_in_order:
		var card := hex.active_tile_card
		if card != null and card.type == TileCard.TileCardType.KITCHENWARE:
			card.apply_board_prep(hex, self)
	_refreshing_prep = false


func _clear_kitchenware_prep() -> void:
	for card: TileCard in _prepped_cards:
		card.clear_prep_state()
	_prepped_cards.clear()
	_passed_into_segment.clear()


## Kitchenware calls this for each card it lends a kind or status to, so the next refresh clears it.
func mark_prepped(card: TileCard) -> void:
	if card != null and card not in _prepped_cards:
		_prepped_cards.append(card)


## Records an Ingredient passed from its station to the next one down. Returns false when its
## station is the bottom one.
func pass_card_down(from_tile: Hex, card: TileCard) -> bool:
	if from_tile == null or card == null or _map == null:
		return false
	var target := _map.get_segment_index(from_tile.coordinates) + 1
	if target <= 0 or target >= _map.get_segment_count():
		return false
	var passed: Array = _passed_into_segment.get(target, [])
	if card not in passed:
		passed.append(card)
	_passed_into_segment[target] = passed
	card.add_prep_status(KitchenwarePrep.STATUS_PASSED)
	mark_prepped(card)
	return true


## Ingredients passed down into this station by a Cutting Board on the station above.
func passed_into_segment(segment_index: int) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card: TileCard in _passed_into_segment.get(segment_index, []):
		result.append(card)
	return result


## The next count Ingredients after tile in fire order, on tile's own station only.
func next_ingredients_on_station(tile: Hex, count: int) -> Array[TileCard]:
	var result: Array[TileCard] = []
	var index := trigger_index(tile)
	if index < 0 or count <= 0 or _map == null:
		return result
	var segment := _map.get_segment_index(tile.coordinates)
	for i in range(index + 1, _hexes_in_order.size()):
		var hex := _hexes_in_order[i]
		if _map.get_segment_index(hex.coordinates) != segment:
			break
		var card := hex.active_tile_card
		if card == null or card.type != TileCard.TileCardType.INGREDIENT:
			continue
		result.append(card)
		if result.size() >= count:
			break
	return result
#endregion --- Kitchenware statuses ---
