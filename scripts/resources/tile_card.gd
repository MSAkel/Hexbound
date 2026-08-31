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
	UTILITY,
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
	ONE_TILE_SEGMENT,
}

# Drops this card from a layout's packs when the map cannot satisfy the requirement.
enum LayoutRequirement {
	NONE,
	REQUIRES_EXACT_SEGMENT_SIZE,
}

# Small icon on placed runes that identifies the card's main role.
enum SigilKind {
	NONE,
	ENERGY,
	MULT,
	GOLD,
	EMPOWER,
	RETRIGGER,
	SEGMENT_RELAY,
	GROWTH,
}

# Honest hex chip. HIDDEN when a number would misrepresent this card.
enum BoardChipMode {
	HIDDEN,
	AMOUNT,
	CHANCE,
	PROGRESS,
}

const EMPOWER_OUTPUT_SCALE := 2.0
const ICON_SCORE := preload("res://assets/icons/resources/score.png")
## Additive Energy pile. Distinct from ICON_SCORE, which is the Energy × Mult product.
const ICON_ENERGY := preload("res://assets/icons/resources/energy.png")
const ICON_GOLD := preload("res://assets/icons/resources/gold.png")
const ICON_MULT := preload("res://assets/icons/resources/multiplier.png")
const SIGIL_TEXTURES := {
	SigilKind.ENERGY: preload("res://assets/icons/sigils/energy_sigil.png"),
	SigilKind.MULT: preload("res://assets/icons/sigils/mult_sigil.png"),
	SigilKind.GOLD: preload("res://assets/icons/sigils/gold_sigil.png"),
	SigilKind.EMPOWER: preload("res://assets/icons/sigils/empower_sigil.png"),
	SigilKind.RETRIGGER: preload("res://assets/icons/sigils/retrigger_sigil.png"),
	SigilKind.SEGMENT_RELAY: preload("res://assets/icons/sigils/segment_relay_sigil.png"),
	SigilKind.GROWTH: preload("res://assets/icons/sigils/growth_sigil.png"),
}

# Fallback prices when a tile card has no rarity set in its resource.
const BASE_PRICE_BY_RARITY := {
	TileCardRarity.COMMON: 2,
	TileCardRarity.UNCOMMON: 5,
	TileCardRarity.RARE: 8,
}

var activation_count: int = 0
var is_active: bool = true
# Runtime buffs from other tile cards, added to the base production amount.
var bonus_production_amount: float = 0.0
# Extra % output from passives such as Growth Capsule, applied on top of other scales.
var personal_output_bonus: float = 0.0
# Activations of this instance during the current run, used by growth passives.
var run_trigger_count: int = 0
# Empowered tile cards double their output once on trigger.
var is_empowered: bool = false
## Short-lived potion fuses sitting on this placed instance.
var potion_fuses: Array[Dictionary] = []
# Scales all tile card output during this activation (score, gold, generated multiplier resource).
var _activation_output_scale: float = 1.0
# True when this activation consumed Empower. Checked by cards that pay extra on Empower.
var _activation_was_empowered: bool = false

@export var base_production_amount: int = 0
@export var rarity: TileCardRarity
@export var type: TileCardType
@export var product: Product = Product.NONE
# only activates once per turn even if retriggered.
@export var single_activation_per_turn: bool = false
# When set, only matching tiles accept this tile card during placement.
@export var placement_restriction: PlacementRestriction = PlacementRestriction.NONE
# Support cards set this explicitly. Producers derive their sigil from product when NONE.
@export var sigil_kind: SigilKind = SigilKind.NONE
## When true, this common score producer may appear in flat-score starter draws.
@export var starting_hand_eligible: bool = false
# Packs and shop omit this card when the selected layout cannot host it.
@export var layout_requirement: LayoutRequirement = LayoutRequirement.NONE
@export var layout_requirement_size: int = 0
# Utilities default to one occupied tile. Transposition uses two.
@export var utility_target_count: int = 1


## False when this layout has no segment that can host the card's requirement.
func is_legal_for_layout(character: CharacterDefinition) -> bool:
	if character == null:
		return true
	match layout_requirement:
		LayoutRequirement.REQUIRES_EXACT_SEGMENT_SIZE:
			return character.has_segment_of_size(layout_requirement_size)
		_:
			return true


func get_sigil_kind() -> SigilKind:
	if sigil_kind != SigilKind.NONE:
		return sigil_kind
	if type != TileCardType.PRODUCER:
		return SigilKind.NONE
	match product:
		Product.SCORE:
			return SigilKind.ENERGY
		Product.MULTIPLIER:
			return SigilKind.MULT
		Product.GOLD:
			return SigilKind.GOLD
		_:
			return SigilKind.NONE


func get_sigil_texture() -> Texture2D:
	var kind := get_sigil_kind()
	if kind == SigilKind.NONE:
		return null
	return SIGIL_TEXTURES.get(kind)

## Switched to identical panel color as its easier to read.
func get_chip_panel_color() -> Color:
	return Color(0.22, 0.16, 0.28)



func get_product_icon() -> Texture2D:
	match product:
		Product.SCORE:
			return ICON_ENERGY
		Product.GOLD:
			return ICON_GOLD
		Product.MULTIPLIER:
			return ICON_MULT
		_:
			return null


func get_inspect_subtitle() -> String:
	var type_label := get_card_kind_label().capitalize()
	var role_label := _get_role_label()
	if type_label.is_empty():
		return role_label
	if role_label.is_empty() or role_label.to_lower() == type_label.to_lower():
		return type_label
	return "%s  ·  %s" % [type_label, role_label]


func _get_role_label() -> String:
	match get_sigil_kind():
		SigilKind.ENERGY:
			return "Energy"
		SigilKind.MULT:
			return "Mult"
		SigilKind.GOLD:
			return "Gold"
		SigilKind.EMPOWER:
			return "Empower"
		SigilKind.RETRIGGER:
			return "Retrigger"
		SigilKind.SEGMENT_RELAY:
			return "Segment Relay"
		SigilKind.GROWTH:
			return "Growth"
		_:
			if product == Product.HYBRID:
				return "Hybrid"
			return ""


# Default chip: producers show amount. Supports show their sigil in the same slot.
func get_board_chip(_tile: Hex = null) -> Dictionary:
	if type != TileCardType.PRODUCER:
		return _sigil_board_chip()
	if product == Product.HYBRID or product == Product.NONE:
		return _hidden_board_chip()
	var amount := _get_production_amount()
	if amount <= 0.0:
		return _hidden_board_chip()
	if product == Product.MULTIPLIER:
		return _amount_board_chip_float(amount)
	return _amount_board_chip(int(round(amount)))


func _sigil_board_chip() -> Dictionary:
	var sigil_texture := get_sigil_texture()
	if sigil_texture == null:
		return _hidden_board_chip()
	return _make_board_chip(BoardChipMode.AMOUNT, "", sigil_texture, get_chip_panel_color())


func _hidden_board_chip() -> Dictionary:
	return _make_board_chip(BoardChipMode.HIDDEN, "", null, Color.WHITE)


## Energy and Gold chips round to a whole number. Pass a float from production helpers.
func _amount_board_chip(amount: Variant, icon: Texture2D = null) -> Dictionary:
	var chip_icon: Texture2D = icon if icon != null else get_product_icon()
	return _make_board_chip(
		BoardChipMode.AMOUNT,
		str(int(round(float(amount)))),
		chip_icon,
		get_chip_panel_color()
	)


func _amount_board_chip_float(amount: float, icon: Texture2D = null) -> Dictionary:
	var chip_icon: Texture2D = icon if icon != null else get_product_icon()
	return _make_board_chip(
		BoardChipMode.AMOUNT,
		CountingNumber.format_mult(amount),
		chip_icon,
		get_chip_panel_color()
	)


func _make_board_chip(
	mode: BoardChipMode,
	text: String,
	icon: Texture2D,
	panel_color: Color,
	detail: String = ""
) -> Dictionary:
	return {
		"mode": mode,
		"text": text,
		"icon": icon,
		"panel_color": panel_color,
		"detail": detail,
	}


func get_card_kind_label() -> String:
	# Saved resources can briefly hold a removed enum index after TileCardType changes.
	var key: Variant = TileCardType.find_key(type)
	if key == null:
		return ""
	return String(key)


func get_save_kind() -> String:
	return "tile_card"


func get_shop_price(discount: float = 0.0) -> int:
	var base_price: int = BASE_PRICE_BY_RARITY.get(rarity, DEFAULT_PRICE)
	return _apply_merchant_discount(base_price, discount)


# Occupied tile for modifiers, empty tile plus placement restrictions for all others.
func can_play_on(hex: Hex) -> bool:
	if hex.is_placement_blocked():
		return false
	if type == TileCardType.UTILITY:
		return hex.active_tile_card != null
	if hex.active_tile_card != null:
		return false
	return can_place_on_tile(hex)


func is_placement_candidate(hex: Hex) -> bool:
	if hex.is_placement_blocked():
		return false
	if type == TileCardType.UTILITY:
		return hex.active_tile_card != null
	return hex.active_tile_card == null


# Instant-resolve modifiers, otherwise occupy the hex.
func play_on(hex: Hex, animate: bool = true) -> void:
	if type == TileCardType.UTILITY:
		apply_on_placement(hex)
	else:
		hex.place_tile_card(self, animate)


# Entry point for tile card activation. Mainly called by Hex.apply_tile_card_activation()
func activate_tile_card(tile: Hex, activation_scale: float = 1.0) -> void:
	if not is_active:
		return

	run_trigger_count += 1
	GameManager.register_tile_card_activation(self)
	EventBus.tile_card_activated.emit(self)

	if tile.map != null:
		GameManager.passive_runtime.before_activation(tile, self)

	var output_scale := activation_scale
	_activation_was_empowered = is_empowered
	if is_empowered:
		# Null Charge still spends Empower. The doubled output never applies.
		if not EventManager.are_empowers_blocked():
			output_scale *= EMPOWER_OUTPUT_SCALE
		is_empowered = false
		EventBus.tile_card_empower_consumed.emit(self)
	if tile.map != null:
		output_scale *= GameManager.passive_runtime.get_output_scale_bonus(tile, self)

	_activation_output_scale = output_scale
	# Count this activation before the card resolves so "triggers so far" includes the current one.
	tile.map.record_segment_trigger_for_tile(tile)
	_on_activate_tile_card(tile)
	if tile.map != null:
		GameManager.passive_runtime.after_activation(tile, self)
		var segment_index := tile.map.get_segment_index(tile.coordinates)
		if tile.map.get_segment_size(segment_index) == 1:
			MetaProgressionManager.add_one_tile_activation()
			MetaProgressionManager.note_one_tile_same_card_triggers(run_trigger_count)
	_try_segment_passive_retrigger(tile)
	PotionManager.after_card_activated(tile, _activation_host_card(tile))
	_activation_output_scale = 1.0
	_activation_was_empowered = false

# Queue extra tile card activations to resolve before tile flow continues.
func queue_tile_card_triggers(source_tile: Hex, tile_cards: Array[TileCard], activation_scales: Array[float] = []) -> void:
	if EventManager.are_retriggers_blocked():
		return
	source_tile.map.queue_tile_card_triggers(tile_cards, activation_scales, source_tile)


## Card occupying the hex this effect is resolving from. Copied scripts (Mirror Copy, Imprint) are not that occupant.
func _activation_host_card(tile: Hex) -> TileCard:
	if tile != null and tile.active_tile_card != null:
		return tile.active_tile_card
	return self


## True when this script is running from another card's hex (Mirror Copy or Imprint replay).
func _is_copied_activation(tile: Hex) -> bool:
	var host := _activation_host_card(tile)
	return host != null and host != self


## Queues only triggerable runes. Shows Failed when nothing valid can fire.
func _try_queue_tile_card_triggers(
	source_tile: Hex,
	tile_cards: Array[TileCard],
	activation_scales: Array[float] = [],
) -> bool:
	if EventManager.are_retriggers_blocked():
		failed_tile_card_text(source_tile)
		return false
	var triggerable: Array[TileCard] = []
	var aligned_scales: Array[float] = []
	var host := _activation_host_card(source_tile)
	for i in range(tile_cards.size()):
		var card := tile_cards[i]
		# Copied effects must not retrigger their host. Skip-self on the copied card misses that instance.
		if _is_copied_activation(source_tile) and card == host:
			continue
		if not _is_triggerable_tile_card(source_tile, card):
			continue
		triggerable.append(card)
		if activation_scales.is_empty():
			continue
		var scale := activation_scales[i] if i < activation_scales.size() else activation_scales[-1]
		aligned_scales.append(scale)

	if triggerable.is_empty():
		failed_tile_card_text(source_tile)
		return false

	if type == TileCardType.SUPPORT:
		for card in triggerable:
			if card.type == TileCardType.PRODUCER:
				MetaProgressionManager.add_support_affected_producer()

	queue_tile_card_triggers(source_tile, triggerable, aligned_scales)
	return true

# Utility cards resolve immediately on placement instead of occupying a tile.
func apply_on_placement(_tile: Hex) -> void:
	pass


## Multi-target utilities collect hexes in the placement handler, then resolve here.
func apply_on_targets(tiles: Array[Hex]) -> void:
	if tiles.is_empty():
		return
	apply_on_placement(tiles[0])


## Occupied-tile utilities cannot retarget a hex already chosen this play.
func can_utility_target(hex: Hex, already_selected: Array[Hex]) -> bool:
	if hex in already_selected:
		return false
	return can_play_on(hex)


## Another card on this segment broke. Salvage Core grows from this hook.
func on_other_segment_card_broke(_broken: TileCard, _tile: Hex) -> void:
	pass


func _try_segment_passive_retrigger(tile: Hex) -> void:
	if tile == null or tile.map == null:
		return
	if not GameManager.passive_runtime.should_retrigger(tile, self):
		return
	_try_queue_tile_card_triggers(tile, [self])


## Isolated RNG for this card's current activation. Same seed and same play replay.
func _effect_rng(tile: Hex, tag: String = "effect") -> RandomNumberGenerator:
	return RunRng.create_card_effect_rng(tile, self, tag)


## Pick a placed rune using this activation's RNG and a coordinate-stable order.
func _pick_random_placed_tile_card(
	tile: Hex,
	candidates: Array[TileCard],
	rng: RandomNumberGenerator
) -> TileCard:
	var tile_map: HexTileMap = tile.map if tile != null else null
	return RunRng.pick_random_placed_tile_card(candidates, rng, tile_map)


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
		PlacementRestriction.ONE_TILE_SEGMENT:
			return tile.map.get_segment_size(tile.map.get_segment_index(tile.coordinates)) == 1
		_:
			return true


# Tile coordinates that would be impacted when this tile card is placed on hover_tile.
# Override in tile cards that trigger or otherwise affect other tiles.
func get_trigger_preview_coords(_hover_tile: Hex) -> Array[Vector2i]:
	return []


#region --- Energy, gold, and multiplier, and floating text helpers ---
func add_score(tile: Hex, base_points: Variant) -> void:
	var points := int(round(float(base_points) * _activation_output_scale))
	tile.map.add_turn_score_for_tile(tile, points)
	_create_floating_text(tile, "+%d" % points, Color.AQUA, ICON_ENERGY)
	PotionManager.relay_product_if_needed(tile, Product.SCORE, points)

func add_gold(tile: Hex, base_amount: Variant) -> void:
	if not EventManager.can_gain_gold():
		return
	var amount := int(round(float(base_amount) * _activation_output_scale))
	amount += GameManager.passive_runtime.extra_gold_for_card(tile, self)
	tile.map.add_turn_gold_for_tile(tile, amount)
	_create_floating_text(tile, "+%d" % amount, Color(1.0, 0.85, 0.2, 1.0), ICON_GOLD)
	PotionManager.relay_product_if_needed(tile, Product.GOLD, amount)

func add_multiplier(tile: Hex, base_amount: Variant, scaled: bool = true) -> void:
	var amount := float(base_amount)
	if scaled:
		amount *= _activation_output_scale
	tile.map.add_turn_multiplier_for_tile(tile, amount)
	_create_floating_text(tile, "+%s" % CountingNumber.format_mult(amount), Color.PLUM, ICON_MULT)
	PotionManager.relay_product_if_needed(tile, Product.MULTIPLIER, amount)


# Credits another segment's Energy. Float stays on this tile, destination segment flashes.
func add_score_to_segment(tile: Hex, segment_index: int, base_points: Variant) -> void:
	if EventManager.are_relays_blocked():
		failed_tile_card_text(tile)
		return
	var points := int(round(float(base_points) * _activation_output_scale))
	tile.map.add_turn_score_for_segment(segment_index, points)
	tile.map.mark_segment_received_relay(segment_index)
	_create_floating_text(tile, "+%d →" % points, Color.AQUA, ICON_ENERGY)
	tile.map.flash_segment_highlight(segment_index)


# Credits another segment's turn multiplier. Float stays on this tile, destination segment flashes.
func add_multiplier_to_segment(tile: Hex, segment_index: int, base_amount: Variant) -> void:
	if EventManager.are_relays_blocked():
		failed_tile_card_text(tile)
		return
	var amount := float(base_amount) * _activation_output_scale
	tile.map.add_turn_multiplier_for_segment(segment_index, amount)
	tile.map.mark_segment_received_relay(segment_index)
	_create_floating_text(tile, "+%s →" % CountingNumber.format_mult(amount), Color.PLUM, ICON_MULT)
	tile.map.flash_segment_highlight(segment_index)


func failed_tile_card_text(tile: Hex) -> void:
	_create_floating_text(tile, "Failed", Color.RED)


## False when this card only resolves from its own trigger-order slot (e.g. Overdrive).
## tile is the hex this instance occupies. Mirror Copy uses it to inherit Overdrive's lock.
func can_be_triggered_by_other_card(_tile: Hex = null) -> bool:
	return not single_activation_per_turn


func _is_triggerable_tile_card(source_tile: Hex, tile_card: TileCard) -> bool:
	if tile_card == null or source_tile.map == null:
		return false
	var target_hex := source_tile.map.get_hex_for_tile_card(tile_card)
	return target_hex != null and source_tile.map.is_tile_card_triggerable(target_hex)


func _filter_triggerable_tile_cards(source_tile: Hex, tile_cards: Array[TileCard]) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card in tile_cards:
		if _is_triggerable_tile_card(source_tile, card):
			result.append(card)
	return result


## Empowers a triggerable rune that is not already empowered.
func _try_empower_tile_card(source_tile: Hex, target: TileCard) -> bool:
	if not _is_triggerable_tile_card(source_tile, target) or target.is_empowered:
		return false
	target._empower()
	if type == TileCardType.SUPPORT:
		MetaProgressionManager.add_support_affected_producer()
	return true


# Queues a newly created card for the hand reveal animation. Does not use tile_card_selected.
func _add_generated_card_to_hand(card: Card) -> void:
	EventBus.generated_hand_card.emit(card)


func _create_floating_text(tile: Hex, text: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, color, icon)

#endregion --- Energy, gold, and multiplier, and floating text helpers ---

func _get_production_amount() -> float:
	return float(base_production_amount) + bonus_production_amount

func _empower() -> void:
	if is_empowered:
		return

	is_empowered = true
	EventBus.tile_card_empowered.emit(self)

func _on_activate_tile_card(_tile: Hex) -> void:
	pass

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
## filter_type: TileCardType (PRODUCER, SUPPORT, UTILITY)
func _count_all_occupied_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> int:
	return tile.map.count_all_occupied_adjacent_tile_cards(tile.coordinates, filter_type)

## All tile cards on map-adjacent hexes around tile (unordered).
## filter_type: TileCardType (PRODUCER, SUPPORT, UTILITY)
func _get_all_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_adjacent_tile_cards(tile, filter_type)


## Adjacent hexes that activate after this tile in trigger order, including empty tiles.
func _get_downstream_adjacent_hexes(tile: Hex) -> Array[Hex]:
	if tile == null or tile.map == null:
		return []
	return tile.map.get_downstream_adjacent_hexes(tile)


## Occupied adjacent Downstream hexes, optionally filtered by card type.
func _get_downstream_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_downstream_adjacent_tile_cards(tile, filter_type)


## Adjacent Downstream Energy producers.
func _get_downstream_adjacent_tile_cards_by_product(tile: Hex, filter_product: Product) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_downstream_adjacent_tile_cards(tile, TileCardType.PRODUCER):
		if tile_card.product != filter_product:
			continue
		result.append(tile_card)
	return result


## Adjacent Downstream Energy producers on this segment.
func _get_downstream_same_segment_producers_by_product(tile: Hex, filter_product: Product) -> Array[TileCard]:
	var segment_index := _get_segment_index(tile)
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_downstream_adjacent_tile_cards_by_product(tile, filter_product):
		var hex := tile.map.get_hex_for_tile_card(tile_card)
		if hex == null:
			continue
		if tile.map.get_segment_index(hex.coordinates) != segment_index:
			continue
		result.append(tile_card)
	return result


## Cards on this segment that activate after this tile, in trigger order.
func _get_later_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var self_index := tile.map._get_hex_trigger_order_index(tile)
	var result: Array[TileCard] = []
	for tile_card: TileCard in _get_all_tile_cards_on_same_segment(tile, filter_type):
		var hex := tile.map.get_hex_for_tile_card(tile_card)
		if hex == null:
			continue
		if tile.map._get_hex_trigger_order_index(hex) > self_index:
			result.append(tile_card)
	result.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		var hex_a := tile.map.get_hex_for_tile_card(a)
		var hex_b := tile.map.get_hex_for_tile_card(b)
		if hex_a == null or hex_b == null:
			return hex_a != null
		return tile.map._get_hex_trigger_order_index(hex_a) < tile.map._get_hex_trigger_order_index(hex_b)
	)
	return result


func _coords_for_downstream_adjacent_tile_cards_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_downstream_adjacent_tile_cards_by_product(tile, filter_product))


func _coords_for_downstream_same_segment_producers_by_product(tile: Hex, filter_product: Product) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_downstream_same_segment_producers_by_product(tile, filter_product))


func _is_first_producer_in_segment(tile: Hex) -> bool:
	for hex: Hex in tile.map.get_hexes_in_segment(_get_segment_index(tile)):
		var card := _effective_producer_on_hex(hex, tile)
		if card == null:
			continue
		return card == self
	return false


func _is_last_producer_in_segment(tile: Hex) -> bool:
	var last: TileCard = null
	for hex: Hex in tile.map.get_hexes_in_segment(_get_segment_index(tile)):
		var card := _effective_producer_on_hex(hex, tile)
		if card == null:
			continue
		last = card
	return last == self


## Treats a hover-preview tile as if this producer were already sitting there.
func _effective_producer_on_hex(hex: Hex, preview_tile: Hex) -> TileCard:
	if hex.active_tile_card != null:
		if hex.active_tile_card.type != TileCardType.PRODUCER:
			return null
		return hex.active_tile_card
	if hex == preview_tile and type == TileCardType.PRODUCER:
		return self
	return null

#endregion --- Adjacent tile card helpers ---

#region --- Trigger order helpers ---
## All adjacent tile cards sorted in the map's global trigger order.
## filter_type: TileCardType (PRODUCER, SUPPORT, UTILITY)
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


## The count hexes immediately before this tile in trigger order, including empties.
func _get_immediately_previous_hexes(tile: Hex, count: int) -> Array[Hex]:
	var result: Array[Hex] = []
	var hexes := tile.map.get_hexes_in_trigger_order()
	var self_index := tile.map._get_hex_trigger_order_index(tile)
	if self_index < 0:
		return result
	for i in range(1, count + 1):
		var prev_index := self_index - i
		if prev_index < 0:
			break
		result.append(hexes[prev_index])
	return result


## Cards sitting on those immediately previous hexes. Empty slots are omitted, not skipped over.
func _get_tile_cards_on_immediately_previous_hexes(tile: Hex, count: int) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for hex: Hex in _get_immediately_previous_hexes(tile, count):
		if hex.active_tile_card == null:
			continue
		result.append(hex.active_tile_card)
	return result


func _coords_for_immediately_previous_hexes(tile: Hex, count: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for hex: Hex in _get_immediately_previous_hexes(tile, count):
		coords.append(hex.coordinates)
	return coords

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
	if tile == null or tile.map == null:
		return -1
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
	if tile == null or tile.map == null:
		return 0
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


## Gold that cards before this tile on the same segment would produce.
## Used by chips so leftover gold from later cards does not inflate the preview.
func _get_earlier_segment_gold_preview(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return 0
	var self_index := tile.map._get_hex_trigger_order_index(tile)
	if self_index < 0:
		return 0
	var gold := 0
	for hex: Hex in tile.map.get_hexes_in_segment(_get_segment_index(tile)):
		if tile.map._get_hex_trigger_order_index(hex) >= self_index:
			continue
		var card := hex.active_tile_card
		if card == null or card.product != Product.GOLD:
			continue
		gold += int(round(card._get_production_amount()))
	return gold


## Energy piled on this segment so far this turn, before Mult.
func _get_segment_turn_score(tile: Hex) -> int:
	return tile.map.get_segment_turn_score(_get_segment_index(tile))


## Turn Mult piled on this segment so far, including the 1.0 base.
func _get_segment_turn_multiplier(tile: Hex) -> float:
	return tile.map.get_segment_turn_multiplier(_get_segment_index(tile))


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


func _get_all_tile_cards_on_later_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_tile_cards_on_later_segments(tile, filter_type)


## Other segments that either host a Producer or do not, depending on want_producer.
func _count_other_segments_by_producer(tile: Hex, want_producer: bool) -> int:
	var self_index := _get_segment_index(tile)
	var count := 0
	for segment_index in range(_get_segment_count(tile)):
		if segment_index == self_index:
			continue
		var has_producer := not tile.map.get_all_tile_cards_on_segment(
			segment_index, TileCardType.PRODUCER
		).is_empty()
		if has_producer == want_producer:
			count += 1
	return count


## Preview tiles in other segments that match Wide Ratio or Tall Cell.
func _coords_for_other_segments_matching_producer(tile: Hex, want_producer: bool) -> Array[Vector2i]:
	var self_index := _get_segment_index(tile)
	var coords: Array[Vector2i] = []
	for segment_index in range(_get_segment_count(tile)):
		if segment_index == self_index:
			continue
		var has_producer := not tile.map.get_all_tile_cards_on_segment(
			segment_index, TileCardType.PRODUCER
		).is_empty()
		if has_producer != want_producer:
			continue
		coords.append_array(_coords_for_segment(tile, segment_index))
	return coords

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
func _destroy_placed_tile_card(source_tile: Hex, tile_card: TileCard, counts_as_break: bool = true) -> void:
	if source_tile == null or source_tile.map == null or tile_card == null:
		return
	var broken_hex := source_tile.map.get_hex_for_tile_card(tile_card)
	if broken_hex == null:
		broken_hex = source_tile
	if counts_as_break:
		if PotionManager.try_prevent_break(tile_card):
			_create_floating_text(source_tile, "Warded", Color(0.45, 0.88, 0.58, 1.0))
			return
		if GameManager.passive_runtime.try_prevent_break(source_tile, tile_card):
			_create_floating_text(source_tile, "Saved", Color(0.55, 0.85, 0.7, 1.0))
			return
		var segment_index := source_tile.map.get_segment_index(broken_hex.coordinates)
		var on_one_tile := segment_index == -1 or source_tile.map.get_segment_size(segment_index) == 1
		MetaProgressionManager.record_card_broken(on_one_tile)
		source_tile.map.notify_card_broke(tile_card)
	source_tile.map.destroy_placed_tile_card(tile_card)


## Remove a placed tile card after its queued chained triggers finish resolving.
func _destroy_placed_tile_card_after_queued_triggers(
	source_tile: Hex,
	tile_card: TileCard,
	on_destroy: Callable = Callable(),
) -> void:
	source_tile.map.schedule_destroy_after_trigger_link(source_tile, tile_card, on_destroy)
#endregion --- Tile card destruction helpers ---


## Random pool card that can occupy a tile. Modifiers are excluded from the roll.
## Pass exclude_id to omit one template so transforms can pick a different card.
func _pick_random_placeable_tile_card(
	rarity: Variant = null,
	exclude_id: String = "",
	rng: RandomNumberGenerator = null
) -> TileCard:
	var candidates: Array[TileCard] = []
	for template: TileCard in GameManager.tile_cards_pool:
		if template.type == TileCardType.UTILITY:
			continue
		if rarity != null and template.rarity != rarity:
			continue
		if not exclude_id.is_empty() and template.id == exclude_id:
			continue
		if not template.is_legal_for_layout(GameManager.selected_character):
			continue
		candidates.append(template)

	if candidates.is_empty():
		return null

	if rng == null:
		return RunRng.pick_random_tile_card(candidates)

	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return a.id < b.id
	)
	return RunRng.pick_random_with(rng, sorted) as TileCard


## Swaps the tile occupant for a fresh instance built from replacement_template.
## Keeps runtime bonus production on the new card.
func _replace_placed_tile_card(tile: Hex, replacement_template: TileCard) -> void:
	if tile.active_tile_card == null or replacement_template == null:
		return

	var old_card := tile.active_tile_card
	var retained_bonus := old_card.bonus_production_amount

	_destroy_placed_tile_card(tile, old_card, false)
	tile.place_tile_card(replacement_template)

	var new_card := tile.active_tile_card
	if new_card == null:
		return

	new_card.bonus_production_amount = retained_bonus
