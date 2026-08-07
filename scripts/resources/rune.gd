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

const EMPOWER_OUTPUT_SCALE := 3.0

var activation_count: int = 0
var is_active: bool = true
# Optional player-applied bonus resolved whenever this rune activates.
var enhancement: Enhancement = null
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


# Entry point for rune activation. Mainly called by Hex.apply_rune_activation()
func activate_rune(tile: Hex, activation_scale: float = 1.0) -> void:
	if not is_active:
		return
	
	# Register before the effect so get_activations_this_turn() includes this rune.
	GameManager.register_rune_activation(self)
	Events.rune_activated.emit(self)
	
	var output_scale := activation_scale
	if is_empowered:
		output_scale *= EMPOWER_OUTPUT_SCALE
		is_empowered = false
		Events.rune_empower_consumed.emit(self)
	
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

#region --- Score, gold, and multiplier, and floating text helpers ---
func add_score(tile: Hex, base_points: int) -> void:
	var points := int(round(base_points * _activation_output_scale))
	GameManager.turn_score += points
	_create_floating_text(tile, "+%d Score" % points, Color.AQUA)

func add_gold(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	GoldManager.add(amount)
	_create_floating_text(tile, "+%d Gold" % amount, Color.GOLD)

func add_multiplier(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	GameManager.turn_multi += amount
	_create_floating_text(tile, "+%d Mult" % amount, Color.PLUM)

func _create_floating_text(tile: Hex, text: String, color: Color = Color.WHITE) -> void:
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, color)

#endregion --- Score, gold, and multiplier, and floating text helpers ---

func _empower() -> void:
	if is_empowered:
		return
	
	is_empowered = true
	Events.rune_empowered.emit(self)

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
# Counts all adjacent tiles occupied by a rune. Pass filter_type to filter by rune type.
func _count_all_occupied_adjacent_runes(tile: Hex, filter_type: Variant = null) -> int:
	return tile.map.count_all_occupied_adjacent_runes(tile.coordinates, filter_type)

# All runes on map-adjacent hexes around tile (unordered).
func _get_all_adjacent_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_adjacent_runes(tile, filter_type)

#endregion --- Adjacent runes helpers ---

#region --- Trigger order helpers ---
# All adjacent runes sorted in the map's global trigger order.
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
# Remove a placed rune instance from the map (clears its tile and cancels queued triggers).
func _destroy_placed_rune(source_tile: Hex, rune: Rune) -> void:
	source_tile.map.destroy_placed_rune(rune)

#endregion --- Rune destruction helpers ---
