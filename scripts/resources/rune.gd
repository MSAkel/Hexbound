class_name Rune
extends Resource

enum RuneRarity { 
	COMMON, 
	UNCOMMON, 
	RARE, 
}

enum RuneType {
	PRODUCER,
	SUPPORT,
	HYBRID,
	MODIFIER,
}

enum Product {
	GOLD,
	SCORE,
	MULTIPLIER,
	HYBRID,
	NONE,
}

# Limits which map tiles can receive this rune during card placement.
enum PlacementRestriction {
	NONE,
	EDGE_TILE,
	SEGMENT_FIRST_TILE,
	SEGMENT_LAST_TILE,
}

const EMPOWER_OUTPUT_SCALE := 3.0

var activation_count: int = 0
var is_active: bool = true
# Optional player-applied bonus resolved whenever this rune activates.
var enhancement: Enhancement = null
# Runtime buffs from other runes, added to the base production amount.
var bonus_production_amount: int = 0
# Empowered runes triple their output once on trigger.
var is_empowered: bool = false
# Scales all rune output during this activation (score, gold, generated multiplier resource).
var _activation_output_scale: float = 1.0

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var base_production_amount: int = 0
@export_multiline var description: String
@export var rarity: RuneRarity
@export var type: RuneType
# @export var boosted_generation_amount: int = 0
@export var product: Product = Product.NONE
# only activates once per turn even if retriggered.
@export var single_activation_per_turn: bool = false
# When set, only matching tiles accept this rune during placement.
@export var placement_restriction: PlacementRestriction = PlacementRestriction.NONE


# Entry point for rune activation. Mainly called by Hex.apply_rune_activation()
func activate_rune(tile: Hex, activation_scale: float = 1.0) -> void:
	if not is_active:
		return
	
	GameManager.register_rune_activation(self)
	EventBus.rune_activated.emit(self)
	
	var output_scale := activation_scale
	if is_empowered:
		output_scale *= EMPOWER_OUTPUT_SCALE
		is_empowered = false
		EventBus.rune_empower_consumed.emit(self)
	
	_activation_output_scale = output_scale
	_on_activate_rune(tile)
	_schedule_enhancement_activation(tile)
	_activation_output_scale = 1.0

# Queue extra rune activations to resolve before tile flow continues.
func queue_rune_triggers(source_tile: Hex, runes: Array[Rune], activation_scales: Array[float] = []) -> void:
	source_tile.map.queue_rune_triggers(runes, activation_scales)

# Modifier cards resolve immediately on placement instead of occupying a tile.
func apply_on_placement(_tile: Hex) -> void:
	pass


func has_placement_restriction() -> bool:
	return placement_restriction != PlacementRestriction.NONE


# Placement validation used by CardPlacementHandler while a rune card is selected.
func can_place_on_tile(tile: Hex) -> bool:
	match placement_restriction:
		PlacementRestriction.EDGE_TILE:
			return _is_on_map_edge(tile)
		PlacementRestriction.SEGMENT_FIRST_TILE:
			return tile.map.is_first_tile_in_segment(tile.coordinates)
		PlacementRestriction.SEGMENT_LAST_TILE:
			return tile.map.is_last_tile_in_segment(tile.coordinates)
		_:
			return true


# Tile coordinates that would be impacted when this rune is placed on hover_tile.
# Override in runes that trigger or otherwise affect other tiles.
func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return []


#region --- Score, gold, and multiplier, and floating text helpers ---
func add_score(tile: Hex, base_points: int) -> void:
	var points := int(round(base_points * _activation_output_scale))
	tile.map.add_turn_score_for_tile(tile, points)
	_create_floating_text(tile, "+%d Score" % points, Color.AQUA)

func add_gold(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	tile.map.add_turn_gold_for_tile(tile, amount)
	_create_floating_text(tile, "+%d Gold" % amount, Color(1.0, 0.85, 0.2, 1.0))

func add_multiplier(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	tile.map.add_turn_multiplier_for_tile(tile, amount)
	_create_floating_text(tile, "+%d Mult" % amount, Color.PLUM)

func _create_floating_text(tile: Hex, text: String, color: Color = Color.WHITE) -> void:
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, color)

#endregion --- Score, gold, and multiplier, and floating text helpers ---

func _get_production_amount() -> int:
	return base_production_amount + bonus_production_amount

func _empower() -> void:
	if is_empowered:
		return
	
	is_empowered = true
	EventBus.rune_empowered.emit(self)

func _on_activate_rune(_tile: Hex) -> void:
	pass

# Brief pause so enhancement floating text does not sit on top of the rune's text.
func _schedule_enhancement_activation(tile: Hex) -> void:
	if enhancement == null:
		return
	tile.map.schedule_delayed_enhancement_activation(self, tile, _activation_output_scale)

# Check if the tile is on the edge of the map.
func _is_on_map_edge(tile: Hex) -> bool:
	return tile.map.is_edge_tile(tile.coordinates)

# Get all runes placed on the map.
func _get_all_placed_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_placed_runes(filter_type)

# Count placed producer runes whose product matches filter_product (e.g. Product.GOLD).
func _get_producer_count_by_product_type(tile: Hex, filter_product: Product) -> int:
	var count := 0
	for rune: Rune in _get_all_placed_runes(tile):
		if rune.type != RuneType.PRODUCER:
			continue
		if rune.product != filter_product:
			continue
		count += 1
	return count

#region --- Adjacent runes helpers ---
## Counts all adjacent tiles occupied by a rune. Pass filter_type to filter by rune type.
## filter_type: RuneType (PRODUCER, SUPPORT, HYBRID, MODIFIER)
func _count_all_occupied_adjacent_runes(tile: Hex, filter_type: Variant = null) -> int:
	return tile.map.count_all_occupied_adjacent_runes(tile.coordinates, filter_type)

## All runes on map-adjacent hexes around tile (unordered).
## filter_type: RuneType (PRODUCER, SUPPORT, HYBRID, MODIFIER)
func _get_all_adjacent_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_adjacent_runes(tile, filter_type)

#endregion --- Adjacent runes helpers ---

#region --- Trigger order helpers ---
## All adjacent runes sorted in the map's global trigger order.
## filter_type: RuneType (PRODUCER, SUPPORT, HYBRID, MODIFIER)
func _get_all_adjacent_runes_in_trigger_order(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_adjacent_runes_in_trigger_order(tile, filter_type)

# Up to count runes that activate after this one in trigger order.
func _get_next_runes_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[Rune]:
	return tile.map.get_next_runes_in_trigger_order(tile, count, filter_type)

# Up to count runes that activated before this one in trigger order.
func _get_previous_runes_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[Rune]:
	return tile.map.get_previous_runes_in_trigger_order(tile, count, filter_type)

# Rune on the next occupied hex in global trigger order (null when empty).
func _get_next_rune_in_trigger_order(tile: Hex) -> Rune:
	return tile.map.get_next_rune_in_trigger_order(tile)

# True when the next rune in trigger order can be consumed in-sequence this turn.
func _can_consume_next_rune_in_trigger_order(tile: Hex) -> bool:
	return tile.map.can_consume_next_rune_in_trigger_order(tile)

#endregion --- Trigger order helpers ---

#region --- Segment helpers ---
# Segments are character-specific groups of tiles (rows for Surveyor, rings for Encircler, etc.).
# Each segment has an index: 0, 1, 2, ... following trigger order.

# Segment index for tile under the active character grouping (-1 when unknown).
func _get_segment_index(tile: Hex) -> int:
	return tile.map.get_segment_index(tile.coordinates)

# All placed runes on the same segment as tile (optional filter_type for Rune.RuneType).
func _get_all_runes_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_runes_on_same_segment(tile, filter_type)


## All placed runes on the same segment whose product matches filter_product.
func _get_all_runes_on_same_segment_by_product(tile: Hex, filter_product: Product) -> Array[Rune]:
	var result: Array[Rune] = []
	for rune: Rune in _get_all_runes_on_same_segment(tile):
		if rune.product != filter_product:
			continue
		result.append(rune)
	return result


## All placed producer runes on the map whose product matches filter_product.
func _get_all_placed_producers_by_product(tile: Hex, filter_product: Product) -> Array[Rune]:
	var result: Array[Rune] = []
	for rune: Rune in _get_all_placed_runes(tile):
		if rune.type != RuneType.PRODUCER:
			continue
		if rune.product != filter_product:
			continue
		result.append(rune)
	return result


## Adjacent producer runes whose product matches filter_product.
func _get_adjacent_runes_by_product(tile: Hex, filter_product: Product) -> Array[Rune]:
	var result: Array[Rune] = []
	for rune: Rune in _get_all_adjacent_runes(tile, RuneType.PRODUCER):
		if rune.product != filter_product:
			continue
		result.append(rune)
	return result


## Adjacent producers of the given product that share this tile's segment.
func _get_adjacent_same_segment_producers_by_product(tile: Hex, filter_product: Product) -> Array[Rune]:
	var segment_index := _get_segment_index(tile)
	var result: Array[Rune] = []
	for rune: Rune in _get_adjacent_runes_by_product(tile, filter_product):
		var hex := tile.map.get_hex_for_rune(rune)
		if hex == null:
			continue
		if tile.map.get_segment_index(hex.coordinates) != segment_index:
			continue
		result.append(rune)
	return result


func _get_all_runes_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_runes_on_other_segments(tile, filter_type)

# Returns the first or last placed rune in a map segment near this tile.
#
# segment_index_offset picks which segment to search, relative to this tile's segment:
#   0  → this tile's segment
#   -1 → the segment immediately before this one
#   -2 → two segments before this one
#   +1 → the segment immediately after this one
# Formula: target segment = this tile's segment index + segment_index_offset
#
# pick_first_in_segment:
#   true  → return the first placed rune in that segment (trigger-order start)
#   false → return the last placed rune in that segment (trigger-order end)
func _get_first_or_last_rune_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> Rune:
	return tile.map.get_rune_in_relative_segment(
		tile, segment_index_offset, pick_first_in_segment, filter_type
	)

#endregion --- Segment helpers ---

#region --- Rune destruction helpers ---
## Resolves placed runes to their map coordinates for placement previews.
func _coords_for_placed_runes(tile: Hex, runes: Array[Rune]) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for rune: Rune in runes:
		var hex := tile.map.get_hex_for_rune(rune)
		if hex != null:
			coords.append(hex.coordinates)
	return coords


## Highlights same-segment runes, optionally filtered by RUNE type.
func _coords_for_same_segment_runes(tile: Hex, filter_type: Variant = null) -> Array[Vector2i]:
	return _coords_for_placed_runes(tile, _get_all_runes_on_same_segment(tile, filter_type))


## Highlights same-segment runes that match a PRODUCT type.
func _coords_for_same_segment_runes_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_runes(tile, _get_all_runes_on_same_segment_by_product(tile, filter_product))


## Highlights all placed producers on the map that match a product type.
func _coords_for_placed_producers_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_runes(tile, _get_all_placed_producers_by_product(tile, filter_product))


## Highlights adjacent producers that match a product type.
func _coords_for_adjacent_runes_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_runes(tile, _get_adjacent_runes_by_product(tile, filter_product))


## Highlights adjacent same-segment producers that match a product type.
func _coords_for_adjacent_same_segment_producers_by_product(
	tile: Hex,
	filter_product: Product
) -> Array[Vector2i]:
	return _coords_for_placed_runes(
		tile,
		_get_adjacent_same_segment_producers_by_product(tile, filter_product)
	)


## Remove a placed rune instance from the map (clears its tile and cancels queued triggers).
func _destroy_placed_rune(source_tile: Hex, rune: Rune) -> void:
	source_tile.map.destroy_placed_rune(rune)

#endregion --- Rune destruction helpers ---
