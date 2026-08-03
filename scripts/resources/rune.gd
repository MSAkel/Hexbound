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

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var score_value: int = 0
@export_multiline var description: String
@export var rarity: RuneRarity
@export var type: RuneType
# @export var boosted_generation_amount: int = 0
@export var product: Product = Product.NONE

var activation_count: int = 0
var is_active: bool = true
# empowered runes produce triple their production amount once on trigger.
var is_empowered: bool = true
# Applied to score gained during this activation (e.g. chain effect penalties).
var _activation_score_multiplier: float = 1.0
# Applied to gold and multiplier output during this activation (e.g. empower).
var _production_multiplier: float = 1.0

const EMPOWER_PRODUCTION_MULTIPLIER := 3.0


func empower() -> void:
	if is_empowered:
		return
	
	is_empowered = true
	Events.rune_empowered.emit(self)


func activate_rune(tile: Hex, score_multiplier: float = 1.0) -> void:
	if not is_active:
		return
	
	# Register before the effect so get_activations_this_turn() includes this rune.
	GameManager.register_rune_activation(self)
	Events.rune_activated.emit(self)
	
	var production_multiplier := 1.0
	if is_empowered:
		production_multiplier = EMPOWER_PRODUCTION_MULTIPLIER
		is_empowered = false
		Events.rune_empower_consumed.emit(self)
	
	_activation_score_multiplier = score_multiplier * production_multiplier
	_production_multiplier = production_multiplier
	_on_activate_rune(tile)
	_activation_score_multiplier = 1.0
	_production_multiplier = 1.0


func _on_activate_rune(_tile: Hex) -> void:
	pass


# Modifier cards resolve immediately on placement instead of occupying a tile.
func apply_on_placement(_tile: Hex) -> void:
	pass


func create_floating_text(tile: Hex, text: String) -> void:
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, false)

func add_score(tile: Hex, base_points: int) -> void:
	var points := int(round(base_points * _activation_score_multiplier))
	GameManager.turn_score += points
	create_floating_text(tile, "+%d score" % points)


func add_gold(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _production_multiplier))
	GoldManager.add(amount)
	create_floating_text(tile, "+%d gold" % amount)


func add_multiplier(tile: Hex, base_amount: int, floating_text: String = "") -> void:
	var amount := int(round(base_amount * _production_multiplier))
	GameManager.turn_multi += amount
	if floating_text.is_empty():
		create_floating_text(tile, "+%d multiplier" % amount)
	else:
		create_floating_text(tile, floating_text)

# Queue extra rune activations to resolve before tile flow continues.
func queue_rune_triggers(source_tile: Hex, runes: Array[Rune], score_multipliers: Array[float] = []) -> void:
	source_tile.map.queue_rune_triggers(runes, score_multipliers)

#region --- Rune context helpers ---
# Counter for the number of runes activated this turn.
func get_activations_this_turn() -> int:
	return GameManager.get_runes_activated_this_turn()

# Check if the tile is on the edge of the map.
func is_on_map_edge(tile: Hex) -> bool:
	return tile.map.is_edge_tile(tile.coordinates)

# Get all runes placed on the map.
func get_all_placed_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_all_placed_runes(filter_type)


# Count placed producer runes whose product matches filter_product (e.g. Product.GOLD).
func get_producer_count(tile: Hex, filter_product: Product) -> int:
	var count := 0
	for rune: Rune in get_all_placed_runes(tile):
		if rune.type != RuneType.PRODUCER:
			continue
		if rune.product != filter_product:
			continue
		count += 1
	return count


func get_all_hexes_with_runes(tile: Hex) -> Array[Hex]:
	return tile.map.get_all_hexes_with_runes()

# Count the number of unoccupied adjacent tiles to the given tile.
func get_unoccupied_adjacent_count(tile: Hex) -> int:
	return tile.map.count_unoccupied_adjacent_hexes(tile.coordinates)


# Pass Rune.RuneType.PRODUCER, Rune.RuneType.EFFECT, or omit filter_type for all occupied neighbors.
func get_occupied_adjacent_count(tile: Hex, filter_type: Variant = null) -> int:
	return tile.map.count_occupied_adjacent_hexes(tile.coordinates, filter_type)


# Occupied runes on map-adjacent hexes around tile.
func get_adjacent_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_adjacent_runes(tile, filter_type)


# Adjacent runes sorted in the map's global trigger order.
func get_adjacent_runes_in_trigger_order(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_adjacent_runes_in_trigger_order(tile, filter_type)


# Runes that activate before/after this one in the current trigger order.
# Pass filter_type (e.g. Rune.RuneType.PRODUCER) to only include matching runes in the result.
func get_runes_in_activation_order(
	tile: Hex,
	count: int = 1,
	before: bool = false,
	filter_type: Variant = null
) -> Array[Rune]:
	return tile.map.get_runes_in_activation_order(tile, count, before, filter_type)


# The rune on the very next hex in trigger order (null when that hex is empty).
func get_immediate_following_rune(tile: Hex) -> Rune:
	return tile.map.get_immediate_following_rune(tile)


# True when the immediate follower can be consumed (in-sequence, not yet activated).
func can_consume_immediate_following_rune(tile: Hex) -> bool:
	return tile.map.can_consume_immediate_following_rune(tile)


# Remove a placed rune instance from the map (clears its tile and cancels queued triggers).
func destroy_placed_rune(source_tile: Hex, rune: Rune) -> void:
	source_tile.map.destroy_placed_rune(rune)


# All placed runes on the same segment as tile (optional filter_type for Rune.RuneType).
func get_runes_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_runes_on_same_segment_as(tile, filter_type)


# Rune on the first tile of each segment (null per segment when empty or filtered out).
func get_runes_on_first_tile_of_each_segment(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_runes_on_first_tile_of_each_segment(filter_type)


# Rune on the last tile of each segment (null per segment when empty or filtered out).
func get_runes_on_last_tile_of_each_segment(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return tile.map.get_runes_on_last_tile_of_each_segment(filter_type)


# First or last occupied rune in a segment relative to tile's segment.
# segment_offset: 0 = current, -1 = previous, 1 = next.
func get_rune_in_segment(
	tile: Hex,
	segment_offset: int,
	first: bool,
	filter_type: Variant = null
) -> Rune:
	return tile.map.get_first_or_last_rune_in_segment(tile, segment_offset, first, filter_type)
#endregion --- Rune context helpers ---
