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
# Applied to score gained during this activation (e.g. chain effect penalties).
var _activation_score_multiplier: float = 1.0

func activate_rune(tile: Hex, score_multiplier: float = 1.0) -> void:
	if not is_active:
		return
	
	# Register before the effect so get_activations_this_turn() includes this rune.
	GameManager.register_rune_activation(self)
	Events.rune_activated.emit(self)
	_activation_score_multiplier = score_multiplier
	_on_activate_rune(tile)
	_activation_score_multiplier = 1.0


func _on_activate_rune(_tile: Hex) -> void:
	pass

func create_floating_text(tile: Hex, text: String) -> void:
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, false)

# Add score using any active activation multiplier and show text on the given tile.
# this function is only handling score, not gold or multiplier.
func add_score(tile: Hex, base_points: int) -> void:
	var points := int(round(base_points * _activation_score_multiplier))
	GameManager.turn_score += points
	create_floating_text(tile, "+%d score" % points)

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
func get_all_placed_runes(tile: Hex) -> Array[Rune]:
	return tile.map.get_all_placed_runes()


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
#endregion --- Rune context helpers ---
