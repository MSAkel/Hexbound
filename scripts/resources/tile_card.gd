class_name TileCard
extends Card

## Base resource for spot cards played on the Feast map.
## Card types are Ingredient, Kitchenware, and Meal.

enum TileCardRarity {
	COMMON,
	UNCOMMON,
	RARE,
}

enum TileCardType {
	INGREDIENT,
	KITCHENWARE,
	MEAL,
}

## Matches seated Ingredient cards when filtering the map by Flavour or Mult producers.
const PRODUCER_TYPE_FILTER: Array[TileCardType] = [TileCardType.INGREDIENT]


static func is_producer_type(card_type: TileCardType) -> bool:
	return card_type == TileCardType.INGREDIENT


static func matches_type_filter(card_type: TileCardType, filter_type: Variant) -> bool:
	if filter_type == null:
		return true
	if filter_type is Array:
		return card_type in filter_type
	return card_type == filter_type

enum Product {
	GOLD,
	FLAVOUR,
	MULTIPLIER, ## Mult
	HYBRID,
	NONE,
}

## ingredient tag catalog.
const TAG_VEGETABLE := &"vegetable"
const TAG_FRUIT := &"fruit"
const TAG_GRAIN := &"grain"
const TAG_PROTEIN := &"protein"
const TAG_SEASONING := &"seasoning"
const TAG_BEVERAGE := &"beverage"
const TAG_KITCHENWARE := &"kitchenware"
const TAG_DISH := &"dish"

## Ingredient tags that may satisfy dish recipe slots.
## Other tags classify cards but are not recipe requirements.
const RECIPE_INGREDIENT_TAGS: Array[StringName] = [
	TAG_VEGETABLE,
	TAG_FRUIT,
	TAG_GRAIN,
	TAG_PROTEIN,
	TAG_SEASONING,
]

# Limits which spots can receive this card during placement.
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

# Whether payout is delivered locally or passed to the next course.
enum RelayMode {
	NONE,
	NEXT_SEGMENT,
}

# Kitchenware ability with no pile output. Composes with relay on pass cards.
enum SupportRole {
	NONE,
	DOUBLE,
	FIRE,
	PROOF,
}

# Honest hex chip. HIDDEN when a number would misrepresent this card.
enum BoardChipMode {
	HIDDEN,
	AMOUNT,
	CHANCE,
	PROGRESS,
}

## Spatial scope for producer and kind queries. Cards pick a scope instead of a lookalike helper name.
enum QueryScope {
	## Map neighbors of this spot.
	ADJACENT,
	## Neighbors that fire after this spot.
	FOLLOWING_ADJACENT,
	## Following neighbors that also share this course.
	FOLLOWING_SAME_SEGMENT,
	## Occupied seats on this course.
	SAME_SEGMENT,
	## Every triggerable seated card on the map.
	PLACED,
}

const EMPOWER_OUTPUT_SCALE := 2.0
## Each Double stack multiplies output by EMPOWER_OUTPUT_SCALE. Two stacks cap at x4.
const MAX_EMPOWER_STACKS := 2
## Shared chip fill. White numbers stay readable on this purple.
const CHIP_PANEL_COLOR := Color(0.22, 0.16, 0.28)
## Pile icons for floating text and Ingredient output chips.
const ICON_FLAVOUR := FeastStatIcons.FLAVOUR
const ICON_GOLD := FeastStatIcons.GOLD
const ICON_MULT := FeastStatIcons.MULT
const ICON_DOUBLE := FeastStatIcons.DOUBLE
const ICON_FIRE := FeastStatIcons.FIRE
const ICON_PASS := FeastStatIcons.PASS

# Fallback merchant prices when a card has no rarity set in its resource.
const BASE_PRICE_BY_RARITY := {
	TileCardRarity.COMMON: 3,
	TileCardRarity.UNCOMMON: 5,
	TileCardRarity.RARE: 8,
}

var activation_count: int = 0
var is_active: bool = true
# Runtime buffs from other cards, added to the base production amount.
var bonus_production_amount: float = 0.0
# Extra % output from passives such as Growth Capsule, applied on top of other scales.
var personal_output_bonus: float = 0.0
# Activations of this instance during the current run, used by growth passives.
var run_trigger_count: int = 0
# Double stacks persist for the rest of the Hour and multiply every fire.
var empower_stacks: int = 0
var is_empowered: bool:
	get:
		return empower_stacks > 0
	set(value):
		if value:
			empower_stacks = maxi(empower_stacks, 1)
		else:
			empower_stacks = 0
## Short-lived condiment fuses sitting on this placed instance.
var condiment_fuses: Array[Dictionary] = []
# Scales all card output during this activation (Flavour, Gold, and Mult).
var _activation_output_scale: float = 1.0
# Cards currently being replayed by Imprint or Mirror Copy. Prevents a nested copy from looping.
static var _copied_activation_stack: Array[TileCard] = []
# True when this activation had at least one Double stack. Checked by cards that pay extra on Double.
var _activation_was_empowered: bool = false
# Flavour this instance paid with add_flavour this Hour. Dishes read the prefix snapshot.
var hour_flavour_produced: int = 0
# Additive Mult this instance paid this Hour, including relays.
var hour_additive_mult_produced: float = 0.0

@export var base_production_amount: int = 0
@export var rarity: TileCardRarity
@export var type: TileCardType
@export var product: Product = Product.NONE
## Recipe membership tags. Use catalog constants such as TAG_VEGETABLE in scripts.
## Array order is inspect display order. Put the primary tag first when it matters.
@export var ingredient_tags: Array[StringName] = []
# only activates once per turn even if retriggered.
@export var single_activation_per_turn: bool = false
# When set, only matching spots accept this card during placement.
@export var placement_restriction: PlacementRestriction = PlacementRestriction.NONE
# Pass cards relay payout to the next course. Kitchenware and Ingredients may both set this.
@export var relay_mode: RelayMode = RelayMode.NONE
# Kitchenware ability role shown on the board chip when the card does not produce a pile.
@export var support_role: SupportRole = SupportRole.NONE
## When true, this common Flavour Ingredient may appear in flat-Flavour starter draws.
@export var starting_hand_eligible: bool = false
# Packs and shop omit this card when the selected layout cannot host it.
@export var layout_requirement: LayoutRequirement = LayoutRequirement.NONE
@export var layout_requirement_size: int = 0
## Plays once when this card resolves during fire order. Chance cards still fire on a miss.
@export var trigger_sound: AudioStream


## Extra per-instance state for a placed card. Saved with the map between loads.
## Shared fields such as activation_count, bonus_production_amount, and run_trigger_count
## are already written by hex_tile_map. Override this for card-specific progress.
func capture_placed_save_state() -> Dictionary:
	return {}


func apply_placed_save_state(_data: Dictionary) -> void:
	pass


## False when this layout has no course that can host the card's requirement.
func is_legal_for_layout(character: CharacterDefinition) -> bool:
	if character == null:
		return true
	match layout_requirement:
		LayoutRequirement.REQUIRES_EXACT_SEGMENT_SIZE:
			return character.has_segment_of_size(layout_requirement_size)
		_:
			return true


func relays_to_next_segment() -> bool:
	return relay_mode == RelayMode.NEXT_SEGMENT


func get_product_icon() -> Texture2D:
	return FeastStatIcons.get_product_icon(product)


func get_relay_icon() -> Texture2D:
	if relays_to_next_segment():
		return FeastStatIcons.get_relay_icon()
	return null


func get_support_icon() -> Texture2D:
	return FeastStatIcons.get_support_icon(support_role)


## Switched to identical panel color as its easier to read.
func get_chip_panel_color() -> Color:
	return CHIP_PANEL_COLOR


## True when this card's tags include tag.
func has_ingredient_tag(tag: StringName) -> bool:
	if tag == &"":
		return false
	return tag in ingredient_tags


## True when card matches a kind tag, an array of tags, or any tag when filter_kind is null.
## TAG_KITCHENWARE matches the Kitchenware card type. Dish and beverage are authored Meal tags.
static func matches_kind_filter(card: TileCard, filter_kind: Variant) -> bool:
	if card == null:
		return false
	if filter_kind == null:
		return true
	if filter_kind is Array:
		for entry in filter_kind:
			if matches_kind_filter(card, entry):
				return true
		return false
	var tag := StringName(str(filter_kind))
	if tag == &"":
		return false
	if tag == TAG_KITCHENWARE:
		return card.type == TileCardType.KITCHENWARE
	return card.has_ingredient_tag(tag)


## Authored tags plus a type-derived Kitchenware tag used by kind queries.
static func queryable_kind_tags(card: TileCard) -> Array[StringName]:
	var tags: Array[StringName] = []
	if card == null:
		return tags
	for tag: StringName in card.ingredient_tags:
		if tag == &"" or tag in tags:
			continue
		tags.append(tag)
	if card.type == TileCardType.KITCHENWARE and TAG_KITCHENWARE not in tags:
		tags.append(TAG_KITCHENWARE)
	return tags


func get_inspect_subtitle() -> String:
	var type_label := get_card_kind_label().capitalize()
	var role_label := _get_role_label()
	var base := ""
	if type_label.is_empty():
		base = role_label
	elif role_label.is_empty() or role_label.to_lower() == type_label.to_lower():
		base = type_label
	else:
		base = "%s  ·  %s" % [type_label, role_label]
	var tag := get_distinct_recipe_tag_label()
	if tag.is_empty() or tag.to_lower() == type_label.to_lower():
		return base
	if base.is_empty():
		return tag
	return "%s  ·  %s" % [base, tag]


# Ingredient and Meal tags such as Vegetable or Dish · Beverage. Empty when none are set.
func get_distinct_recipe_tag_label() -> String:
	if type != TileCardType.INGREDIENT and type != TileCardType.MEAL:
		return ""
	var tag := FeastDisplay.format_ingredient_tags_label(ingredient_tags)
	if tag.is_empty():
		return ""
	var type_label := FeastDisplay.get_tile_card_type_label(self)
	if tag.to_lower() == type_label.to_lower():
		return ""
	return tag


func get_card_type_display() -> String:
	var type_label := FeastDisplay.get_tile_card_type_label(self)
	var tag := get_distinct_recipe_tag_label()
	if tag.is_empty():
		return type_label
	return "%s · %s" % [type_label, tag]


func _get_role_label() -> String:
	return FeastDisplay.get_role_label(product, relay_mode, support_role)


# Default chip: Ingredients show amount. Kitchenware shows their role icon in the same slot.
# Uses _effect_amount so chips stay honest when a card scales from the board.
func get_board_chip(tile: Hex = null) -> Dictionary:
	if is_producer_type(type):
		if product == Product.HYBRID or product == Product.NONE:
			return _hidden_board_chip()
		var amount := _effect_amount(tile)
		if amount <= 0.0:
			return _hidden_board_chip()
		var chip: Dictionary
		if product == Product.MULTIPLIER:
			chip = _amount_board_chip_float(amount)
		else:
			chip = _amount_board_chip(int(round(amount)))
		if relays_to_next_segment():
			chip = _compose_board_chip(chip, ICON_PASS)
		return chip
	if support_role != SupportRole.NONE:
		return _support_role_chip(support_role)
	if relays_to_next_segment():
		return _relay_only_chip()
	return _hidden_board_chip()


func _stat_board_chip() -> Dictionary:
	if support_role != SupportRole.NONE:
		return _support_role_chip(support_role)
	if relays_to_next_segment():
		return _relay_only_chip()
	return _hidden_board_chip()


func _support_role_chip(role: SupportRole) -> Dictionary:
	var role_texture := FeastStatIcons.get_support_icon(role)
	if role_texture == null:
		return _hidden_board_chip()
	return _make_board_chip(BoardChipMode.AMOUNT, "", role_texture, CHIP_PANEL_COLOR)


func _relay_only_chip() -> Dictionary:
	var relay_texture := get_relay_icon()
	if relay_texture == null:
		return _hidden_board_chip()
	return _make_board_chip(BoardChipMode.AMOUNT, "", relay_texture, CHIP_PANEL_COLOR)


func _compose_board_chip(base_chip: Dictionary, extra_icon: Texture2D, extra_text: String = "") -> Dictionary:
	var chip := base_chip.duplicate()
	chip["extra_icon"] = extra_icon
	if not extra_text.is_empty():
		chip["extra_text"] = extra_text
	return chip


func _hidden_board_chip() -> Dictionary:
	return _make_board_chip(BoardChipMode.HIDDEN, "", null, Color.WHITE)


## Flavour and Gold chips round to a whole number. Pass a float from production helpers.
func _amount_board_chip(amount: Variant, amount_icon: Texture2D = null) -> Dictionary:
	var value := float(amount)
	var chip_icon: Texture2D = amount_icon if amount_icon != null else get_product_icon()
	return _make_board_chip(
		BoardChipMode.AMOUNT,
		str(int(round(value))),
		chip_icon,
		CHIP_PANEL_COLOR,
		"",
		value
	)


## Additive Mult chip. Same panel as Flavour, with a +n.n label.
func _amount_board_chip_float(amount: float, amount_icon: Texture2D = null) -> Dictionary:
	var chip_icon: Texture2D = amount_icon if amount_icon != null else get_product_icon()
	return _make_board_chip(
		BoardChipMode.AMOUNT,
		CountingNumber.format_additive_mult(amount),
		chip_icon,
		CHIP_PANEL_COLOR,
		"",
		amount
	)


## Flavour number plus additive Mult on the same chip. Used by hybrid dishes.
func _dual_amount_board_chip(flavour_amount: int, mult_amount: float) -> Dictionary:
	var chip := _amount_board_chip(flavour_amount, ICON_FLAVOUR)
	chip["extra_text"] = CountingNumber.format_additive_mult(mult_amount)
	chip["extra_icon"] = ICON_MULT
	chip["extra_amount"] = mult_amount
	return chip


## Course ×Mult chip. Uses an x prefix so it does not look like additive +Mult.
func _multiplicative_mult_board_chip(amount: float, amount_icon: Texture2D = null) -> Dictionary:
	var chip_icon: Texture2D = amount_icon if amount_icon != null else ICON_MULT
	return _make_board_chip(
		BoardChipMode.AMOUNT,
		CountingNumber.format_multiplicative_mult(amount),
		chip_icon,
		CHIP_PANEL_COLOR,
		"",
		amount
	)


func _make_board_chip(
	mode: BoardChipMode,
	text: String,
	chip_icon: Texture2D,
	panel_color: Color,
	detail: String = "",
	amount: float = 0.0
) -> Dictionary:
	return {
		"mode": mode,
		"text": text,
		"icon": chip_icon,
		"panel_color": panel_color,
		"detail": detail,
		"amount": amount,
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


# Empty spot plus placement restrictions.
func can_play_on(hex: Hex) -> bool:
	if hex.is_placement_blocked():
		return false
	if hex.active_tile_card != null:
		return false
	return can_place_on_tile(hex)


func is_placement_candidate(hex: Hex) -> bool:
	if hex.is_placement_blocked():
		return false
	return hex.active_tile_card == null


func play_on(hex: Hex, animate: bool = true) -> void:
	hex.place_tile_card(self, animate)


# Entry point for spot card activation. Mainly called by Hex.apply_tile_card_activation()
func activate_tile_card(tile: Hex, activation_scale: float = 1.0) -> void:
	if not is_active:
		return

	run_trigger_count += 1
	GameManager.register_tile_card_activation(self)
	EventBus.tile_card_activated.emit(self)

	if tile.map != null:
		GameManager.passive_runtime.before_activation(tile, self)

	var output_scale := activation_scale
	_activation_was_empowered = empower_stacks > 0
	if empower_stacks > 0 and not EventManager.are_empowers_blocked():
		output_scale *= pow(EMPOWER_OUTPUT_SCALE, empower_stacks)
	if tile.map != null:
		output_scale *= GameManager.passive_runtime.get_output_scale_bonus(tile, self)

	_activation_output_scale = output_scale
	# Count this activation before the card resolves so "triggers so far" includes the current one.
	tile.map.record_segment_trigger_for_tile(tile)
	_on_activate_tile_card(tile)
	_play_trigger_sound()
	if tile.map != null:
		GameManager.passive_runtime.after_activation(tile, self)
		var segment_index := tile.map.get_segment_index(tile.coordinates)
		if tile.map.get_segment_size(segment_index) == 1:
			MetaProgressionManager.add_one_tile_activation()
			MetaProgressionManager.note_one_tile_same_card_triggers(run_trigger_count)
	_try_segment_passive_retrigger(tile)
	CondimentManager.after_card_activated(tile, _activation_host_card(tile))
	_activation_output_scale = 1.0
	_activation_was_empowered = false

# Queue extra spot card activations to resolve before fire flow continues.
func queue_tile_card_triggers(source_tile: Hex, tile_cards: Array[TileCard], activation_scales: Array[float] = []) -> void:
	if EventManager.are_retriggers_blocked():
		return
	source_tile.map.queue_tile_card_triggers(tile_cards, activation_scales, source_tile)


## Card occupying the spot this effect is resolving from. Copied scripts (Mirror Copy, Imprint) are not that occupant.
func _activation_host_card(tile: Hex) -> TileCard:
	if tile != null and tile.active_tile_card != null:
		return tile.active_tile_card
	return self


## True when this script is running from another card's spot (Mirror Copy or Imprint replay).
func _is_copied_activation(tile: Hex) -> bool:
	var host := _activation_host_card(tile)
	return host != null and host != self


## Drop leftover copy-chain entries if a script error aborted a nested replay.
static func clear_copied_activation_stack() -> void:
	_copied_activation_stack.clear()


## Replay another card's effect from host_tile. The same instance cannot re-enter this chain.
func _run_copied_activation(copied: TileCard, host_tile: Hex) -> void:
	if copied == null:
		return
	# Copied Imprint looks at the host's previous spots, which can include this same card.
	if copied in _copied_activation_stack:
		return
	var stack_depth := _copied_activation_stack.size()
	_copied_activation_stack.append(copied)
	copied._activation_output_scale = _activation_output_scale
	copied._on_activate_tile_card(host_tile)
	copied._activation_output_scale = 1.0
	# Trim this frame even if a nested copy aborted without popping.
	while _copied_activation_stack.size() > stack_depth:
		_copied_activation_stack.pop_back()


## Queues only triggerable spot cards. Shows Failed when nothing valid can fire.
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

	if type == TileCardType.KITCHENWARE:
		for card in triggerable:
			if is_producer_type(card.type):
				MetaProgressionManager.add_support_affected_producer()

	queue_tile_card_triggers(source_tile, triggerable, aligned_scales)
	return true

# Utility cards used to resolve immediately on placement. Board tools moved to condiments.
func apply_on_placement(_tile: Hex) -> void:
	pass


## Another card on this course broke. Salvage Core grows from this hook.
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


## Pick a placed spot card using this activation's RNG and a coordinate-stable order.
func _pick_random_placed_tile_card(
	tile: Hex,
	candidates: Array[TileCard],
	rng: RandomNumberGenerator
) -> TileCard:
	var tile_map: HexTileMap = tile.map if tile != null else null
	return RunRng.pick_random_placed_tile_card(candidates, rng, tile_map)


func has_placement_restriction() -> bool:
	return placement_restriction != PlacementRestriction.NONE


# Placement validation used by CardPlacementHandler while a spot card is selected.
func can_place_on_tile(tile: Hex) -> bool:
	match placement_restriction:
		PlacementRestriction.EDGE_TILE:
			return tile.map.is_edge_tile(tile.coordinates)
		PlacementRestriction.SEGMENT_FIRST_TILE:
			return tile.map.is_first_tile_in_segment(tile.coordinates)
		PlacementRestriction.SEGMENT_LAST_TILE:
			return tile.map.is_last_tile_in_segment(tile.coordinates)
		PlacementRestriction.ONE_TILE_SEGMENT:
			return tile.map.get_segment_size(tile.map.get_segment_index(tile.coordinates)) == 1
		_:
			return true


# Spot coordinates that would be impacted when this card is placed on hover_tile.
# Override when the preview is not a placed-card list from _effect_preview_cards.
func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _effect_preview_cards(hover_tile))


## Seats that count toward this card's output. Dishes override with matching prefix tags.
func get_trigger_preview_gold_coords(_hover_tile: Hex) -> Array[Vector2i]:
	return []


## Occupied prefix seats whose tags cannot fill this card's recipe. Empty for non-dishes.
func get_trigger_preview_invalid_coords(_hover_tile: Hex) -> Array[Vector2i]:
	return []


#region --- Flavour, Gold, Mult, and floating text helpers ---
func add_flavour(tile: Hex, base_points: Variant) -> void:
	var points := int(round(float(base_points) * _activation_output_scale))
	hour_flavour_produced += points
	tile.map.add_turn_flavour_for_tile(tile, points)
	_create_floating_text(tile, "+%d" % points, Color.AQUA, ICON_FLAVOUR, null, _payout_float_is_doubled())
	CondimentManager.relay_product_if_needed(tile, Product.FLAVOUR, points)

func add_gold(tile: Hex, base_amount: Variant) -> void:
	if not EventManager.can_gain_gold():
		return
	var amount := int(round(float(base_amount) * _activation_output_scale))
	amount += GameManager.passive_runtime.extra_gold_for_card(tile, self)
	tile.map.add_turn_gold_for_tile(tile, amount)
	_create_floating_text(tile, "+%d" % amount, Color(1.0, 0.85, 0.2, 1.0), ICON_GOLD, null, _payout_float_is_doubled())
	CondimentManager.relay_product_if_needed(tile, Product.GOLD, amount)

func add_additive_mult(tile: Hex, base_amount: Variant, scaled: bool = true) -> void:
	var amount := float(base_amount)
	if scaled:
		amount *= _activation_output_scale
	hour_additive_mult_produced += amount
	tile.map.add_turn_additive_mult_for_tile(tile, amount)
	_create_floating_text(
		tile,
		CountingNumber.format_additive_mult(amount),
		Color.PLUM,
		ICON_MULT,
		null,
		_payout_float_is_doubled(scaled)
	)
	CondimentManager.relay_product_if_needed(tile, Product.MULTIPLIER, amount)


func multiply_multiplicative_mult(tile: Hex, factor: Variant, scaled: bool = true) -> void:
	var amount := float(factor)
	if scaled:
		amount *= _activation_output_scale
	tile.map.multiply_turn_multiplicative_mult_for_tile(tile, amount)
	_create_floating_text(
		tile,
		CountingNumber.format_multiplicative_mult(amount),
		Color.PLUM,
		ICON_MULT,
		null,
		_payout_float_is_doubled(scaled)
	)


# Credits another course's additive Mult. Float stays on this spot.
func add_additive_mult_to_segment(tile: Hex, segment_index: int, base_amount: Variant) -> void:
	if EventManager.are_relays_blocked():
		failed_tile_card_text(tile)
		return
	var amount := float(base_amount) * _activation_output_scale
	hour_additive_mult_produced += amount
	tile.map.add_turn_additive_mult_for_segment(segment_index, amount)
	tile.map.mark_segment_received_relay(segment_index)
	_create_floating_text(
		tile,
		"%s" % CountingNumber.format_additive_mult(amount),
		Color.PLUM,
		ICON_PASS,
		ICON_MULT,
		_payout_float_is_doubled()
	)


# Credits another course's multiplicative Mult. Float stays on this spot.
func multiply_multiplicative_mult_to_segment(tile: Hex, segment_index: int, factor: Variant) -> void:
	if EventManager.are_relays_blocked():
		failed_tile_card_text(tile)
		return
	var amount := float(factor) * _activation_output_scale
	tile.map.multiply_turn_multiplicative_mult_for_segment(segment_index, amount)
	tile.map.mark_segment_received_relay(segment_index)
	_create_floating_text(
		tile,
		"%s →" % CountingNumber.format_multiplicative_mult(amount),
		Color.PLUM,
		ICON_MULT,
		null,
		_payout_float_is_doubled()
	)


# Credits another course's Flavour. Float stays on this spot.
func add_flavour_to_segment(tile: Hex, segment_index: int, base_points: Variant) -> void:
	if EventManager.are_relays_blocked():
		failed_tile_card_text(tile)
		return
	var points := int(round(float(base_points) * _activation_output_scale))
	hour_flavour_produced += points
	tile.map.add_turn_flavour_for_segment(segment_index, points)
	tile.map.mark_segment_received_relay(segment_index)
	_create_floating_text(tile, "+%d" % points, Color.AQUA, ICON_PASS, ICON_FLAVOUR, _payout_float_is_doubled())


func failed_tile_card_text(tile: Hex) -> void:
	_create_floating_text(tile, "Failed", Color.RED)


## False when this card only resolves from its own fire-order slot (e.g. Overdrive).
## tile is the spot this instance occupies. Mirror Copy uses it to inherit Overdrive's lock.
func can_be_triggered_by_other_card(_tile: Hex = null) -> bool:
	return not single_activation_per_turn


func _is_triggerable_tile_card(source_tile: Hex, tile_card: TileCard) -> bool:
	if tile_card == null or source_tile.map == null:
		return false
	var target_hex := source_tile.map.get_hex_for_tile_card(tile_card)
	return target_hex != null and source_tile.map.is_tile_card_triggerable(target_hex)


## Adds one Double stack to a triggerable spot card, up to MAX_EMPOWER_STACKS.
func _try_empower_tile_card(source_tile: Hex, target: TileCard) -> bool:
	if not _is_triggerable_tile_card(source_tile, target):
		return false
	if not target._empower():
		return false
	if type == TileCardType.KITCHENWARE:
		MetaProgressionManager.add_support_affected_producer()
	return true


# Queues a newly created card for the hand reveal animation. Does not use tile_card_selected.
func _add_generated_card_to_hand(card: Card) -> void:
	EventBus.generated_hand_card.emit(card)


func _create_floating_text(
	tile: Hex,
	text: String,
	color: Color = Color.WHITE,
	text_icon: Texture2D = null,
	target_icon: Texture2D = null,
	doubled: bool = false
) -> void:
	var tile_pos := tile.map.floating_text_position_for_hex(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, color, text_icon, target_icon, doubled)


# True when this fire had Double stacks and the payout was actually scaled.
# Null Charge blocks the scale, but those floats stay normal.
func _payout_float_is_doubled(scaled: bool = true) -> bool:
	return scaled and _activation_was_empowered and not EventManager.are_empowers_blocked()


## Kitchenware target feedback as [ability icon] [target card icon].
func _create_targeted_ability_floating_text(
	tile: Hex,
	ability_icon: Texture2D,
	target: TileCard
) -> void:
	if target.icon == null:
		return
	_create_floating_text(tile, "", Color.WHITE, ability_icon, target.icon)


## Kitchenware double feedback.
func _create_doubled_floating_text(tile: Hex, target: TileCard) -> void:
	_create_targeted_ability_floating_text(tile, ICON_DOUBLE, target)


## Kitchenware fire feedback.
func _create_fired_floating_text(tile: Hex, target: TileCard) -> void:
	_create_targeted_ability_floating_text(tile, ICON_FIRE, target)


## Shared activation blip for every fire, including misses with no float text.
func _play_trigger_sound() -> void:
	if GameManager.should_skip_turn_presentation():
		return
	AudioManager.play_card_trigger_chop()

#endregion --- Flavour, Gold, Mult, and floating text helpers ---

func _get_production_amount() -> float:
	return float(base_production_amount) + bonus_production_amount


## Amount this card should pay and show. Override instead of duplicating chip and activate math.
func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount()


## Placed cards this effect cares about. Default preview maps these to coordinates.
func _effect_preview_cards(_tile: Hex) -> Array[TileCard]:
	return []


## Pays _effect_amount using this card's product. Silent when the amount is empty.
func _pay_effect_amount(tile: Hex) -> void:
	var amount := _effect_amount(tile)
	match product:
		Product.FLAVOUR:
			if amount <= 0.0:
				return
			add_flavour(tile, amount)
		Product.MULTIPLIER:
			if is_zero_approx(amount):
				return
			add_additive_mult(tile, amount)
		Product.GOLD:
			if amount <= 0.0:
				return
			add_gold(tile, amount)


## Adds one Double stack. Returns false when already at MAX_EMPOWER_STACKS.
func _empower() -> bool:
	if empower_stacks >= MAX_EMPOWER_STACKS:
		return false

	empower_stacks += 1
	EventBus.tile_card_empowered.emit(self)
	return true


## Clears all Double stacks at Hour end.
func clear_empower() -> void:
	if empower_stacks <= 0:
		return

	empower_stacks = 0
	EventBus.tile_card_empower_consumed.emit(self)

func _on_activate_tile_card(_tile: Hex) -> void:
	pass


#region --- Map query helpers ---
# Get all spot cards placed on the map.
func _get_all_placed_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_placed_tile_cards(filter_type)


## All cards on map-adjacent spots around tile (unordered).
func _get_all_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_adjacent_tile_cards(tile, filter_type)


## Adjacent spots that fire after this spot in fire order, including empty spots.
func _get_following_adjacent_hexes(tile: Hex) -> Array[Hex]:
	if tile == null or tile.map == null:
		return []
	return tile.map.get_following_adjacent_hexes(tile)


## Occupied adjacent Following spots, optionally filtered by card type.
func _get_following_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_following_adjacent_tile_cards(tile, filter_type)


## Cards on this course that fire after this spot, in fire order.
func _get_later_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_later_tile_cards_on_same_segment(tile, filter_type)


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


## Treats a hover-preview spot as if this Ingredient were already sitting there.
func _effective_producer_on_hex(hex: Hex, preview_tile: Hex) -> TileCard:
	if hex.active_tile_card != null:
		if not is_producer_type(hex.active_tile_card.type):
			return null
		return hex.active_tile_card
	if hex == preview_tile and is_producer_type(type):
		return self
	return null


# Up to count spot cards that fire after this one in fire order.
func _get_next_tile_cards_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	return tile.map.get_next_tile_cards_in_trigger_order(tile, count, filter_type)


# Up to count spot cards that fired before this one in fire order.
func _get_previous_tile_cards_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	return tile.map.get_previous_tile_cards_in_trigger_order(tile, count, filter_type)


## The count spots immediately before this spot in fire order, including empties.
## These are contiguous previous seats. Gaps and wrong cards are not skipped.
func _get_immediately_previous_hexes(tile: Hex, count: int) -> Array[Hex]:
	if tile == null or tile.map == null:
		return []
	return tile.map.get_immediately_previous_hexes(tile, count)


## Cards sitting on those immediately previous spots. Empty slots are omitted, not skipped over.
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


## Clears Hour Flavour and Mult snapshots before this Hour's fire order starts.
func reset_hour_product_snapshot() -> void:
	hour_flavour_produced = 0
	hour_additive_mult_produced = 0.0


# Spot card on the next occupied spot in global fire order (null when empty).
func _get_next_tile_card_in_trigger_order(tile: Hex) -> TileCard:
	return tile.map.get_next_tile_card_in_trigger_order(tile)


# Course index for tile under the active character grouping (-1 when unknown).
func _get_segment_index(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return -1
	return tile.map.get_segment_index(tile.coordinates)


# Number of spots in this card's course (0 when the course is unknown).
func _get_segment_size(tile: Hex) -> int:
	return tile.map.get_segment_size(_get_segment_index(tile))


func _get_segment_count(tile: Hex) -> int:
	return tile.map.get_segment_count()


# Next course after this spot, or -1 when this spot is already on the last course.
func _get_next_segment_index(tile: Hex) -> int:
	var next_segment_index := _get_segment_index(tile) + 1
	if next_segment_index < 0 or next_segment_index >= _get_segment_count(tile):
		return -1
	return next_segment_index


# All placed spot cards on the same course as tile (optional filter_type for TileCard.TileCardType).
func _get_all_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_tile_cards_on_same_segment(tile, filter_type)


# Activations on this course so far this hour, including the current activation.
func _get_segment_trigger_count_this_turn(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return 0
	return tile.map.get_segment_turn_trigger_count(_get_segment_index(tile))


## Flavour piled on this course so far this hour, before Mult.
func _get_segment_turn_flavour(tile: Hex) -> int:
	return tile.map.get_segment_turn_flavour(_get_segment_index(tile))


## Additive Mult piled on this course so far this hour, including the 1.0 base.
func _get_segment_additive_mult(tile: Hex) -> float:
	return tile.map.get_segment_additive_mult(_get_segment_index(tile))


## Placed cards in a spatial scope. Optional type filter such as PRODUCER_TYPE_FILTER.
func _cards_in_scope(tile: Hex, scope: QueryScope, filter_type: Variant = null) -> Array[TileCard]:
	if tile == null or tile.map == null:
		return []
	match scope:
		QueryScope.ADJACENT:
			return _get_all_adjacent_tile_cards(tile, filter_type)
		QueryScope.FOLLOWING_ADJACENT:
			return _get_following_adjacent_tile_cards(tile, filter_type)
		QueryScope.FOLLOWING_SAME_SEGMENT:
			return _cards_on_same_segment(_get_following_adjacent_tile_cards(tile, filter_type), tile)
		QueryScope.SAME_SEGMENT:
			return _get_all_tile_cards_on_same_segment(tile, filter_type)
		QueryScope.PLACED:
			return _get_all_placed_tile_cards(tile, filter_type)
		_:
			return []


## Keeps cards that sit on the same course as tile.
func _cards_on_same_segment(cards: Array[TileCard], tile: Hex) -> Array[TileCard]:
	var segment_index := _get_segment_index(tile)
	var result: Array[TileCard] = []
	for card: TileCard in cards:
		var hex := tile.map.get_hex_for_tile_card(card)
		if hex == null:
			continue
		if tile.map.get_segment_index(hex.coordinates) != segment_index:
			continue
		result.append(card)
	return result


## Seated Ingredients in scope whose product matches filter_product.
func _producers_by_product(tile: Hex, filter_product: Product, scope: QueryScope) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card: TileCard in _cards_in_scope(tile, scope, PRODUCER_TYPE_FILTER):
		if card.product != filter_product:
			continue
		result.append(card)
	return result


## Cards in scope matching a kind tag. Includes Kitchenware and Dish when those tags are used.
func _cards_by_kind(tile: Hex, filter_kind: Variant, scope: QueryScope) -> Array[TileCard]:
	return _filter_tile_cards_by_kind(_cards_in_scope(tile, scope), filter_kind)


## Keeps only cards that match filter_kind.
func _filter_tile_cards_by_kind(cards: Array[TileCard], filter_kind: Variant) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card: TileCard in cards:
		if matches_kind_filter(card, filter_kind):
			result.append(card)
	return result


func _get_all_tile_cards_on_later_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return tile.map.get_all_tile_cards_on_later_segments(tile, filter_type)


## Other course indexes that either host an Ingredient or do not, depending on want_producer.
func _other_segment_indexes_matching_producer(tile: Hex, want_producer: bool) -> Array[int]:
	var self_index := _get_segment_index(tile)
	var matches: Array[int] = []
	for segment_index in range(_get_segment_count(tile)):
		if segment_index == self_index:
			continue
		var has_producer := not tile.map.get_all_tile_cards_on_segment(
			segment_index, PRODUCER_TYPE_FILTER
		).is_empty()
		if has_producer == want_producer:
			matches.append(segment_index)
	return matches


func _count_other_segments_by_producer(tile: Hex, want_producer: bool) -> int:
	return _other_segment_indexes_matching_producer(tile, want_producer).size()


## Preview spots in other courses that match Wide Ratio or Tall Cell.
func _coords_for_other_segments_matching_producer(tile: Hex, want_producer: bool) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for segment_index in _other_segment_indexes_matching_producer(tile, want_producer):
		coords.append_array(_coords_for_segment(tile, segment_index))
	return coords


# Returns the first or last placed spot card in a map course near this spot.
#
# segment_index_offset picks which course to search, relative to this spot's course:
#   0  → this spot's course
#   -1 → the course immediately before this one
#   -2 → two courses before this one
#   +1 → the course immediately after this one
# Formula: target course = this spot's course index + segment_index_offset
#
# pick_first_in_segment:
#   true  → return the first placed card in that course (fire-order start)
#   false → return the last placed card in that course (fire-order end)
func _get_first_or_last_tile_card_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> TileCard:
	return tile.map.get_tile_card_in_relative_segment(
		tile, segment_index_offset, pick_first_in_segment, filter_type
	)


## Spot on the opposite side of the map from tile, or null when that cell is missing.
func _get_opposite_hex(tile: Hex) -> Hex:
	return tile.map.get_opposite_hex(tile.coordinates)


## Placement preview for the spot whose ability this card would copy.
func _coords_for_opposite_tile(tile: Hex) -> Array[Vector2i]:
	var opposite := _get_opposite_hex(tile)
	if opposite == null or opposite == tile:
		return []
	return [opposite.coordinates]


## Resolves placed spot cards to their map coordinates for placement previews.
func _coords_for_placed_tile_cards(tile: Hex, tile_cards: Array[TileCard]) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if tile == null or tile.map == null:
		return coords
	for tile_card: TileCard in tile_cards:
		var hex := tile.map.get_hex_for_tile_card(tile_card)
		if hex != null:
			coords.append(hex.coordinates)
	return coords


## Highlights same-course spot cards, optionally filtered by card type.
func _coords_for_same_segment_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _get_all_tile_cards_on_same_segment(tile, filter_type))


func _coords_for_producers_by_product(
	tile: Hex,
	filter_product: Product,
	scope: QueryScope
) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _producers_by_product(tile, filter_product, scope))


func _coords_for_cards_by_kind(tile: Hex, filter_kind: Variant, scope: QueryScope) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _cards_by_kind(tile, filter_kind, scope))


## All spots in a course, used to preview where forwarded Flavour or Mult will land.
func _coords_for_segment(tile: Hex, segment_index: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if tile == null or tile.map == null or segment_index < 0:
		return coords
	for hex: Hex in tile.map.get_hexes_in_segment(segment_index):
		coords.append(hex.coordinates)
	return coords


## Spots in the course after this one. Empty when this spot is on the last course.
func _coords_for_next_segment(tile: Hex) -> Array[Vector2i]:
	return _coords_for_segment(tile, _get_next_segment_index(tile))

#endregion --- Map query helpers ---


## Remove a placed spot card instance from the map (clears its spot and cancels queued triggers).
func _destroy_placed_tile_card(source_tile: Hex, tile_card: TileCard, counts_as_break: bool = true) -> void:
	if source_tile == null or source_tile.map == null or tile_card == null:
		return
	var broken_hex := source_tile.map.get_hex_for_tile_card(tile_card)
	if broken_hex == null:
		broken_hex = source_tile
	if counts_as_break:
		if CondimentManager.try_prevent_break(tile_card):
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


## Removes a placed card during resolve without counting as a spoil.
## Skips Ward, break-save, and on_other_segment_card_broke. Replaces do not use this path.
func _consume_placed_tile_card(source_tile: Hex, tile_card: TileCard) -> void:
	if source_tile == null or source_tile.map == null or tile_card == null:
		return
	if source_tile.map.get_hex_for_tile_card(tile_card) == null:
		return
	RunLedger.record_card_consumed(tile_card)
	_destroy_placed_tile_card(source_tile, tile_card, false)


## Permanent production growth that survives days and is saved with the placed card.
func _grow_permanent(source_tile: Hex, target: TileCard, amount: float, reason: String = "") -> void:
	if target == null or amount == 0.0:
		return
	target.bonus_production_amount += amount
	RunLedger.record_permanent_growth(amount)
	if source_tile == null or source_tile.map == null:
		return
	var target_hex := source_tile.map.get_hex_for_tile_card(target)
	if target_hex == null:
		target_hex = source_tile
	var label := reason
	if label.is_empty():
		var gained := int(round(amount))
		if gained >= 0:
			label = "Gained +%d" % gained
		else:
			label = "Gained %d" % gained
	_create_floating_text(target_hex, label, Color.AQUA)
	target_hex.refresh_tile_card_visual_state()


## Remove a placed spot card after its queued chained triggers finish resolving.
func _destroy_placed_tile_card_after_queued_triggers(
	source_tile: Hex,
	tile_card: TileCard,
	on_destroy: Callable = Callable(),
) -> void:
	source_tile.map.schedule_destroy_after_trigger_link(source_tile, tile_card, on_destroy)
#endregion --- Spot card destruction helpers ---


## Random pool card that can occupy a spot. Utilities are excluded from the roll.
## Pass exclude_id to omit one template so transforms can pick a different card.
func _pick_random_placeable_tile_card(
	filter_rarity: Variant = null,
	exclude_id: String = "",
	rng: RandomNumberGenerator = null
) -> TileCard:
	var candidates: Array[TileCard] = []
	for template: TileCard in GameManager.tile_cards_pool:
		if filter_rarity != null and template.rarity != filter_rarity:
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


## Swaps the spot occupant for a fresh instance built from replacement_template.
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
