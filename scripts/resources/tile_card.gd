class_name TileCard
extends Card

##This was originally a rune, but was renamed to TileCard
## Need to update the entire code base to use TileCard instead of Rune

enum TileCardRarity {
	COMMON,
	UNCOMMON,
	RARE,
}

enum TileCardType {
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

# Limits which map tiles can receive this tile card during placement.
enum PlacementRestriction {
	NONE,
	EDGE_TILE,
	SEGMENT_FIRST_TILE,
	SEGMENT_LAST_TILE,
}

const EMPOWER_OUTPUT_SCALE := 2.0
const ICON_SCORE := preload("res://assets/icons/currency/score.png")
const ICON_GOLD := preload("res://assets/icons/currency/gold.png")
const ICON_MULT := preload("res://assets/icons/currency/multiplier.png")

# Fallback prices when a tile card has no rarity set in its resource.
const BASE_PRICE_BY_RARITY := {
	TileCardRarity.COMMON: 15,
	TileCardRarity.UNCOMMON: 30,
	TileCardRarity.RARE: 45,
}

var activation_count: int = 0
var is_active: bool = true
# Optional player-applied bonus resolved whenever this tile card activates.
var enhancement: Enhancement = null
# Runtime buffs from other tile cards, added to the base production amount.
var bonus_production_amount: int = 0
# Empowered tile cards triple their output once on trigger.
var is_empowered: bool = false
# Scales all tile card output during this activation (score, gold, generated multiplier resource).
var _activation_output_scale: float = 1.0

@export var base_production_amount: int = 0
@export var rarity: TileCardRarity
@export var type: TileCardType
@export var product: Product = Product.NONE
# only activates once per turn even if retriggered.
@export var single_activation_per_turn: bool = false
# When set, only matching tiles accept this tile card during placement.
@export var placement_restriction: PlacementRestriction = PlacementRestriction.NONE


func get_card_kind_label() -> String:
	return TileCardType.keys()[type]


func get_save_kind() -> String:
	return "tile_card"


func get_shop_price(discount: float = 0.0) -> int:
	var base_price: int = BASE_PRICE_BY_RARITY.get(rarity, DEFAULT_PRICE)
	return _apply_merchant_discount(base_price, discount)


# Occupied tile for modifiers, empty tile plus placement restrictions for all others.
func can_play_on(hex: Hex) -> bool:
	if hex.is_disabled_by_difficulty:
		return false
	if type == TileCardType.MODIFIER:
		return hex.active_tile_card != null
	if hex.active_tile_card != null:
		return false
	return can_place_on_tile(hex)


func is_placement_candidate(hex: Hex) -> bool:
	if hex.is_disabled_by_difficulty:
		return false
	if type == TileCardType.MODIFIER:
		return hex.active_tile_card != null
	return hex.active_tile_card == null


# Instant-resolve modifiers, otherwise occupy the hex.
func play_on(hex: Hex) -> void:
	if type == TileCardType.MODIFIER:
		apply_on_placement(hex)
	else:
		hex.place_tile_card(self)


# Entry point for tile card activation. Mainly called by Hex.apply_tile_card_activation()
func activate_tile_card(tile: Hex, activation_scale: float = 1.0) -> void:
	if not is_active:
		return

	GameManager.register_tile_card_activation(self)
	EventBus.tile_card_activated.emit(self)

	var output_scale := activation_scale
	if is_empowered:
		output_scale *= EMPOWER_OUTPUT_SCALE
		is_empowered = false
		EventBus.tile_card_empower_consumed.emit(self)

	_activation_output_scale = output_scale
	# Count this activation before the card resolves so "triggers so far" includes the current one.
	tile.map.record_segment_trigger_for_tile(tile)
	_on_activate_tile_card(tile)
	_schedule_enhancement_activation(tile)
	_activation_output_scale = 1.0

# Queue extra tile card activations to resolve before tile flow continues.
func queue_tile_card_triggers(source_tile: Hex, tile_cards: Array[TileCard], activation_scales: Array[float] = []) -> void:
	source_tile.map.queue_tile_card_triggers(tile_cards, activation_scales)

# Modifier cards resolve immediately on placement instead of occupying a tile.
func apply_on_placement(_tile: Hex) -> void:
	pass


func has_placement_restriction() -> bool:
	return placement_restriction != PlacementRestriction.NONE


# Placement validation used by CardPlacementHandler while a tile card is selected.
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


# Tile coordinates that would be impacted when this tile card is placed on hover_tile.
# Override in tile cards that trigger or otherwise affect other tiles.
func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return []


#region --- Score, gold, and multiplier, and floating text helpers ---
func add_score(tile: Hex, base_points: int) -> void:
	var points := int(round(base_points * _activation_output_scale))
	tile.map.add_turn_score_for_tile(tile, points)
	_create_floating_text(tile, "+%d" % points, Color.AQUA, ICON_SCORE)

func add_gold(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	tile.map.add_turn_gold_for_tile(tile, amount)
	_create_floating_text(tile, "+%d" % amount, Color(1.0, 0.85, 0.2, 1.0), ICON_GOLD)

func add_multiplier(tile: Hex, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	tile.map.add_turn_multiplier_for_tile(tile, amount)
	_create_floating_text(tile, "+%d" % amount, Color.PLUM, ICON_MULT)


# Credits another segment's turn score. Float stays on this tile, destination segment flashes.
func add_score_to_segment(tile: Hex, segment_index: int, base_points: int) -> void:
	var points := int(round(base_points * _activation_output_scale))
	tile.map.add_turn_score_for_segment(segment_index, points)
	_create_floating_text(tile, "+%d → next" % points, Color.AQUA, ICON_SCORE)
	tile.map.flash_segment_highlight(segment_index)


# Credits another segment's turn multiplier. Float stays on this tile, destination segment flashes.
func add_multiplier_to_segment(tile: Hex, segment_index: int, base_amount: int) -> void:
	var amount := int(round(base_amount * _activation_output_scale))
	tile.map.add_turn_multiplier_for_segment(segment_index, amount)
	_create_floating_text(tile, "+%d → next" % amount, Color.PLUM, ICON_MULT)
	tile.map.flash_segment_highlight(segment_index)


func failed_tile_card_text(tile: Hex) -> void:
	_create_floating_text(tile, "Failed", Color.RED)


# Queues a newly created card for the hand reveal animation. Does not use tile_card_selected.
func _add_generated_card_to_hand(card: Card) -> void:
	EventBus.generated_hand_card.emit(card)


func _create_floating_text(tile: Hex, text: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, color, icon)

#endregion --- Score, gold, and multiplier, and floating text helpers ---

func _get_production_amount() -> int:
	return base_production_amount + bonus_production_amount

func _empower() -> void:
	if is_empowered:
		return

	is_empowered = true
	EventBus.tile_card_empowered.emit(self)

func _on_activate_tile_card(_tile: Hex) -> void:
	pass

# Enhancement text stacks above the host rune float. No delay is needed.
func _schedule_enhancement_activation(tile: Hex) -> void:
	if enhancement == null:
		return
	tile.map.schedule_delayed_enhancement_activation(self, tile, _activation_output_scale)

# Check if the tile is on the edge of the map.
func _is_on_map_edge(tile: Hex) -> bool:
	return tile.map.is_edge_tile(tile.coordinates)

# Get all tile cards placed on the map.
func _get_all_placed_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_placed_tile_cards(filter_type)

# Count placed producer tile cards whose product matches filter_product (e.g. Product.GOLD).
func _get_producer_count_by_product_type(tile: Hex, filter_product: Product) -> int:
	var count := 0
	for tile_card: TileCard in _get_all_placed_tile_cards(tile):
		if tile_card.type != TileCardType.PRODUCER:
			continue
		if tile_card.product != filter_product:
			continue
		count += 1
	return count

#region --- Adjacent tile card helpers ---
## Counts all adjacent tiles occupied by a tile card. Pass filter_type to filter by type.
## filter_type: TileCardType (PRODUCER, SUPPORT, HYBRID, MODIFIER)
func _count_all_occupied_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> int:
	return tile.map.count_all_occupied_adjacent_tile_cards(tile.coordinates, filter_type)

## All tile cards on map-adjacent hexes around tile (unordered).
## filter_type: TileCardType (PRODUCER, SUPPORT, HYBRID, MODIFIER)
func _get_all_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_adjacent_tile_cards(tile, filter_type)

#endregion --- Adjacent tile card helpers ---

#region --- Trigger order helpers ---
## All adjacent tile cards sorted in the map's global trigger order.
## filter_type: TileCardType (PRODUCER, SUPPORT, HYBRID, MODIFIER)
func _get_all_adjacent_tile_cards_in_trigger_order(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_adjacent_tile_cards_in_trigger_order(tile, filter_type)

# Up to count tile cards that activate after this one in trigger order.
func _get_next_tile_cards_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	return tile.map.get_next_tile_cards_in_trigger_order(tile, count, filter_type)

# Up to count tile cards that activated before this one in trigger order.
func _get_previous_tile_cards_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	return tile.map.get_previous_tile_cards_in_trigger_order(tile, count, filter_type)

# Tile card on the next occupied hex in global trigger order (null when empty).
func _get_next_tile_card_in_trigger_order(tile: Hex) -> TileCard:
	return tile.map.get_next_tile_card_in_trigger_order(tile)

# True when the next tile card in trigger order can be consumed in-sequence this turn.
func _can_consume_next_tile_card_in_trigger_order(tile: Hex) -> bool:
	return tile.map.can_consume_next_tile_card_in_trigger_order(tile)

#endregion --- Trigger order helpers ---

#region --- Segment helpers ---
# Segments are character-specific groups of tiles (rows for Surveyor, rings for Encircler, etc.).
# Each segment has an index: 0, 1, 2, ... following trigger order.

# Segment index for tile under the active character grouping (-1 when unknown).
func _get_segment_index(tile: Hex) -> int:
	return tile.map.get_segment_index(tile.coordinates)

# Number of tiles in this card's segment (0 when the segment is unknown).
func _get_segment_size(tile: Hex) -> int:
	return tile.map.get_segment_size(_get_segment_index(tile))

func _get_segment_count(tile: Hex) -> int:
	return tile.map.get_segment_count()


# Next segment after this tile, or -1 when this tile is already on the last segment.
func _get_next_segment_index(tile: Hex) -> int:
	var next_segment_index := _get_segment_index(tile) + 1
	if next_segment_index < 0 or next_segment_index >= _get_segment_count(tile):
		return -1
	return next_segment_index

# All placed tile cards on the same segment as tile (optional filter_type for TileCard.TileCardType).
func _get_all_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_tile_cards_on_same_segment(tile, filter_type)


# Activations on this tile's segment so far this turn, including the current activation.
func _get_segment_trigger_count_this_turn(tile: Hex) -> int:
	return tile.map.get_segment_turn_trigger_count(_get_segment_index(tile))


# Extra activations beyond each card's first trigger on this segment this turn.
func _get_segment_retrigger_count_this_turn(tile: Hex) -> int:
	var retrigger_count := 0
	for tile_card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		var activations := GameManager.get_tile_card_activation_count_this_turn(tile_card)
		if activations > 1:
			retrigger_count += activations - 1
	return retrigger_count


func _get_segment_turn_gold(tile: Hex) -> int:
	return tile.map.get_segment_turn_gold(_get_segment_index(tile))

## All placed tile cards on the same segment whose product matches filter_product.
func _get_all_tile_cards_on_same_segment_by_product(tile: Hex, filter_product: Product) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		if tile_card.product != filter_product:
			continue
		result.append(tile_card)
	return result


## All placed producer tile cards on the map whose product matches filter_product.
func _get_all_placed_producers_by_product(tile: Hex, filter_product: Product) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_all_placed_tile_cards(tile):
		if tile_card.type != TileCardType.PRODUCER:
			continue
		if tile_card.product != filter_product:
			continue
		result.append(tile_card)
	return result


## Adjacent producer tile cards whose product matches filter_product.
func _get_adjacent_tile_cards_by_product(tile: Hex, filter_product: Product) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_all_adjacent_tile_cards(tile, TileCardType.PRODUCER):
		if tile_card.product != filter_product:
			continue
		result.append(tile_card)
	return result


## Adjacent producers of the given product that share this tile's segment.
func _get_adjacent_same_segment_producers_by_product(tile: Hex, filter_product: Product) -> Array[TileCard]:
	var segment_index := _get_segment_index(tile)
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_adjacent_tile_cards_by_product(tile, filter_product):
		var hex := tile.map.get_hex_for_tile_card(tile_card)
		if hex == null:
			continue
		if tile.map.get_segment_index(hex.coordinates) != segment_index:
			continue
		result.append(tile_card)
	return result


func _get_all_tile_cards_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_tile_cards_on_other_segments(tile, filter_type)

# Returns the first or last placed tile card in a map segment near this tile.
#
# segment_index_offset picks which segment to search, relative to this tile's segment:
#   0  → this tile's segment
#   -1 → the segment immediately before this one
#   -2 → two segments before this one
#   +1 → the segment immediately after this one
# Formula: target segment = this tile's segment index + segment_index_offset
#
# pick_first_in_segment:
#   true  → return the first placed tile card in that segment (trigger-order start)
#   false → return the last placed tile card in that segment (trigger-order end)
func _get_first_or_last_tile_card_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> TileCard:
	return tile.map.get_tile_card_in_relative_segment(
		tile, segment_index_offset, pick_first_in_segment, filter_type
	)

#endregion --- Segment helpers ---

#region --- Opposite tile helpers ---
## Hex on the opposite side of the map from tile, or null when that cell is missing.
func _get_opposite_hex(tile: Hex) -> Hex:
	return tile.map.get_opposite_hex(tile.coordinates)


## Placement preview for the tile whose ability this card would copy.
func _coords_for_opposite_tile(tile: Hex) -> Array[Vector2i]:
	var opposite := _get_opposite_hex(tile)
	if opposite == null or opposite == tile:
		return []
	return [opposite.coordinates]

#endregion --- Opposite tile helpers ---

#region --- Tile card destruction helpers ---
## Resolves placed tile cards to their map coordinates for placement previews.
func _coords_for_placed_tile_cards(tile: Hex, tile_cards: Array[TileCard]) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for tile_card: TileCard in tile_cards:
		var hex := tile.map.get_hex_for_tile_card(tile_card)
		if hex != null:
			coords.append(hex.coordinates)
	return coords


## Highlights same-segment tile cards, optionally filtered by TILE CARD type.
func _coords_for_same_segment_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_all_tile_cards_on_same_segment(tile, filter_type))


## Highlights same-segment tile cards that match a PRODUCT type.
func _coords_for_same_segment_tile_cards_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_all_tile_cards_on_same_segment_by_product(tile, filter_product))


## Highlights all placed producers on the map that match a product type.
func _coords_for_placed_producers_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_all_placed_producers_by_product(tile, filter_product))


## Highlights adjacent producers that match a product type.
func _coords_for_adjacent_tile_cards_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_adjacent_tile_cards_by_product(tile, filter_product))


## Highlights adjacent same-segment producers that match a product type.
func _coords_for_adjacent_same_segment_producers_by_product(
	tile: Hex,
	filter_product: Product
) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(
		tile,
		_get_adjacent_same_segment_producers_by_product(tile, filter_product)
	)


## All tiles in a segment, used to preview where forwarded score or mult will land.
func _coords_for_segment(tile: Hex, segment_index: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if segment_index < 0:
		return coords
	for hex: Hex in tile.map.get_hexes_in_segment(segment_index):
		coords.append(hex.coordinates)
	return coords


## Tiles in the segment after this one. Empty when this tile is on the last segment.
func _coords_for_next_segment(tile: Hex) -> Array[Vector2i]:
	return _coords_for_segment(tile, _get_next_segment_index(tile))


## Remove a placed tile card instance from the map (clears its tile and cancels queued triggers).
func _destroy_placed_tile_card(source_tile: Hex, tile_card: TileCard) -> void:
	source_tile.map.destroy_placed_tile_card(tile_card)
#endregion --- Tile card destruction helpers ---


## Random pool card that can occupy a tile. Modifiers are excluded from the roll.
## Pass exclude_id to omit one template so transforms can pick a different card.
func _pick_random_placeable_tile_card(
	rarity: Variant = null,
	exclude_id: String = ""
) -> TileCard:
	var candidates: Array[TileCard] = []
	for template: TileCard in GameManager.tile_cards_pool:
		if template.type == TileCardType.MODIFIER:
			continue
		if rarity != null and template.rarity != rarity:
			continue
		if not exclude_id.is_empty() and template.id == exclude_id:
			continue
		candidates.append(template)

	if candidates.is_empty():
		return null

	return candidates.pick_random()


## Swaps the tile occupant for a fresh instance built from replacement_template.
## Keeps runtime bonus production and any attached enhancement on the new card.
func _replace_placed_tile_card(tile: Hex, replacement_template: TileCard) -> void:
	if tile.active_tile_card == null or replacement_template == null:
		return

	var old_card := tile.active_tile_card
	var retained_bonus := old_card.bonus_production_amount
	var retained_enhancement: Enhancement = null
	if old_card.enhancement != null:
		retained_enhancement = old_card.enhancement.duplicate(true)

	_destroy_placed_tile_card(tile, old_card)
	tile.place_tile_card(replacement_template)

	var new_card := tile.active_tile_card
	if new_card == null:
		return

	new_card.bonus_production_amount = retained_bonus
	if retained_enhancement == null:
		return

	new_card.enhancement = retained_enhancement
	# setup() may have already finished before the enhancement was copied.
	if tile.rune_ui != null:
		tile.rune_ui.show_enhancement(retained_enhancement)

