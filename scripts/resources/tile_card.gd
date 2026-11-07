class_name TileCard
extends Card

## Base resource for spot cards played on the Feast map.
## Card types are Ingredient, Kitchenware, and Meal.

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
const TAG_MEAT := &"meat"
const TAG_SEAFOOD := &"seafood"
const TAG_DAIRY := &"dairy"
const TAG_SWEET := &"sweet"
const TAG_SEASONING := &"seasoning"
const TAG_BEVERAGE := &"beverage"
const TAG_KITCHENWARE := &"kitchenware"
const TAG_DISH := &"dish"

## Ingredient tags that may satisfy dish recipe slots.
## Other tags classify cards but are not recipe requirements.
const RECIPE_INGREDIENT_TAGS: Array[StringName] = [
	TAG_VEGETABLE,
	TAG_FRUIT,
	TAG_MEAT,
	TAG_SEAFOOD,
	TAG_DAIRY,
	TAG_SWEET,
	TAG_SEASONING,
]

# Kitchenware ability shown on the board chip next to any flat Mult it pays.
enum SupportRole {
	NONE,
	GARNISH,
	FIRE,
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
	## Following neighbors that also share this station.
	FOLLOWING_SAME_SEGMENT,
	## Occupied seats on this station.
	SAME_SEGMENT,
	## Every triggerable seated card on the map.
	PLACED,
}

## Each Garnish stack adds this much output scale (untuned): 1 stack x1.75, 2 stacks x2.5.
## Stacks add, they do not multiply. Use garnish_scale_for(). Garnish never scales Gold.
const GARNISH_SCALE_PER_STACK := 0.75
## Staff can raise the cap. Read StaffManager.max_garnish_stacks_for() for a seated card.
const MAX_GARNISH_STACKS := 2
## Kitchenware pays its printed Mult plus this much for each Ingredient it prepares (untuned).
const KITCHENWARE_MULT_PER_PREP := 1.0
## Shared chip fill. White numbers stay readable on this purple.
const CHIP_PANEL_COLOR := Color(0.22, 0.16, 0.28)
## Pile icons for floating text and Ingredient output chips.
const ICON_FLAVOUR := FeastStatIcons.FLAVOUR
const ICON_GOLD := FeastStatIcons.GOLD
const ICON_MULT := FeastStatIcons.MULT
const ICON_GARNISH := FeastStatIcons.GARNISH
const ICON_FIRE := FeastStatIcons.FIRE

## Spot cards have no rarity. Ingredients and Kitchenware share one merchant price, Meals cost more.
const SHOP_PRICE := 3
const MEAL_SHOP_PRICE := 4
## Playing a copy onto the same card merges it up one star. Each star past the first adds this much
## Flavour, Gold and +Mult scale. xMult is never star-scaled, so starred Mult cards do not compound.
const MAX_STAR_LEVEL := 5
const STAR_SCALE_STEP := 0.25

## What playing a hand card onto a hex would do.
enum Overplay { NONE, PLACE, MERGE, REPLACE }
## Debug A/B switch for the playtest runner. False keeps cards to empty spots.
static var overplay_enabled := true

var activation_count: int = 0
var is_active: bool = true
# Merge level of this placed instance. Scales all output. Hand and shop cards are always 1.
var star_level: int = 1
# Activations of this instance during the current run.
var run_trigger_count: int = 0
# Garnish stacks wait on the card until it next triggers (across Hours), then boost every trigger
# of that card for the rest of that Hour and are used up when the Hour ends. Whatever is still
# waiting at the end of the Day is cleared (StationManager.on_day_ended).
var garnish_stacks: int = 0
# Hours the Garnish lasts once it starts boosting. Set when the first stack lands. Preserving adds one.
var garnish_hours_left: int = 0
# True when a Garnish boosted one of this card's triggers this Hour. Lobster Roll reads it, and
# end_hour_garnish spends one of garnish_hours_left for it.
var hour_was_garnished: bool = false
# Kinds a Kitchenware status lends this seated card (Seasoned, Blended). Runtime only:
# KitchenwarePrep rebuilds it from the board whenever a seat changes.
var granted_kind_tags: Array[StringName] = []
# Kitchenware statuses on this seated card (KitchenwarePrep.STATUS_*). Runtime only, like above.
var prep_statuses: Array[StringName] = []
# Ingredients this Kitchenware prepared this Hour, counted each time (a retrigger, a Garnish stack,
# a status). Fried Meals read the Deep Fryer's count.
var hour_prepared_count: int = 0
# Run-long growth station perks store on this card (Seasoned Grill). Saved with the card.
var perk_growth: Dictionary = {}
var is_garnished: bool:
	get:
		return garnish_stacks > 0
	set(value):
		if value:
			garnish_stacks = maxi(garnish_stacks, 1)
		else:
			garnish_stacks = 0
## Short-lived condiment fuses sitting on this placed instance.
var condiment_fuses: Array[Dictionary] = []
# One-shot output scale (from _try_scale_tile_card; no card uses it since Skillet and Deep Fryer became retriggers). Consumed by the next activation, cleared at Hour end.
var pending_output_scale: float = 1.0
# Scales all card output during this activation: the product of Garnish, chef, Station, star,
# neighbour and queued scales. Flavour and +Mult take it whole. xMult takes it as
# 1 + (factor - 1) x scale, so only the part above x1 grows. Gold takes it without the Garnish part.
var _activation_output_scale: float = 1.0
# Garnish part of _activation_output_scale. Divided back out for Gold.
var _activation_garnish_scale: float = 1.0
# True when this activation had at least one Garnish stack. Checked by cards that pay extra on Garnish.
var _activation_was_garnished: bool = false
# Station flat Flavour still to fold into this activation's first Flavour payout (before scaling).
var _activation_flat_bonus: int = 0
# Flavour this instance paid with add_flavour this Hour. Dishes read the station snapshot.
var hour_flavour_produced: int = 0
# Additive Mult this instance paid this Hour.
var hour_additive_mult_produced: float = 0.0

@export var base_production_amount: int = 0
@export var type: TileCardType
@export var product: Product = Product.NONE
## Recipe membership tags. Use catalog constants such as TAG_VEGETABLE in scripts.
## Array order is inspect display order. Put the primary tag first when it matters.
@export var ingredient_tags: Array[StringName] = []
# only activates once per turn even if retriggered.
@export var single_activation_per_turn: bool = false
# Kitchenware ability role shown on the board chip next to its flat Mult.
@export var support_role: SupportRole = SupportRole.NONE
## When true, this card may be dealt in the opening hand.
@export var starting_hand_eligible: bool = false


## Extra per-instance state for a placed card. Saved with the map between loads.
## Shared fields such as activation_count, star_level, and run_trigger_count
## are already written by hex_tile_map. Override this for card-specific progress.
func capture_placed_save_state() -> Dictionary:
	return {}


func apply_placed_save_state(_data: Dictionary) -> void:
	pass


func get_product_icon() -> Texture2D:
	return FeastStatIcons.get_product_icon(product)


## Switched to identical panel color as its easier to read.
func get_chip_panel_color() -> Color:
	return CHIP_PANEL_COLOR


## True when this card's tags include tag, counting kinds a Kitchenware status lends it
## (Seasoned, Blended). Station setups read has_authored_ingredient_tag instead.
func has_ingredient_tag(tag: StringName) -> bool:
	if tag == &"":
		return false
	return tag in ingredient_tags or tag in granted_kind_tags


## True when the card's own printed tags include tag. Kitchenware statuses do not count.
func has_authored_ingredient_tag(tag: StringName) -> bool:
	if tag == &"":
		return false
	return tag in ingredient_tags


## Printed tags plus kinds lent by Kitchenware statuses, without duplicates.
func get_kind_tags() -> Array[StringName]:
	if granted_kind_tags.is_empty():
		return ingredient_tags
	var tags: Array[StringName] = ingredient_tags.duplicate()
	for tag: StringName in granted_kind_tags:
		if tag not in tags:
			tags.append(tag)
	return tags


## Lends kinds to this seated card (Seasoned, Blended). KitchenwarePrep clears them on every refresh.
func grant_kind_tags(tags: Array[StringName], status: StringName) -> void:
	for tag: StringName in tags:
		if tag != &"" and tag not in ingredient_tags and tag not in granted_kind_tags:
			granted_kind_tags.append(tag)
	add_prep_status(status)


func add_prep_status(status: StringName) -> void:
	if status != &"" and status not in prep_statuses:
		prep_statuses.append(status)


func clear_prep_state() -> void:
	granted_kind_tags.clear()
	prep_statuses.clear()


## True when card matches a kind tag, an array of tags, or any tag when filter_kind is null.
## TAG_KITCHENWARE matches the Kitchenware card type. Dish and beverage are authored Meal tags.
## include_granted false ignores kinds lent by Kitchenware statuses (station setups).
static func matches_kind_filter(card: TileCard, filter_kind: Variant, include_granted: bool = true) -> bool:
	if card == null:
		return false
	if filter_kind == null:
		return true
	if filter_kind is Array:
		for entry in filter_kind:
			if matches_kind_filter(card, entry, include_granted):
				return true
		return false
	var tag := StringName(str(filter_kind))
	if tag == &"":
		return false
	if tag == TAG_KITCHENWARE:
		return card.type == TileCardType.KITCHENWARE
	if include_granted:
		return card.has_ingredient_tag(tag)
	return card.has_authored_ingredient_tag(tag)


## Kind tags (printed and lent) plus a type-derived Kitchenware tag used by kind queries.
static func queryable_kind_tags(card: TileCard) -> Array[StringName]:
	var tags: Array[StringName] = []
	if card == null:
		return tags
	for tag: StringName in card.get_kind_tags():
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
	var subtitle := base
	if not tag.is_empty() and tag.to_lower() != type_label.to_lower():
		subtitle = tag if base.is_empty() else "%s  ·  %s" % [base, tag]
	# Kitchenware statuses on a seated card, such as "Seasoned".
	for status: StringName in prep_statuses:
		subtitle = "%s  ·  %s" % [subtitle, String(status).capitalize()] if not subtitle.is_empty() else String(status).capitalize()
	return subtitle


# Ingredient and Meal tags such as Vegetable or Dish · Beverage. Empty when none are set.
func get_distinct_recipe_tag_label() -> String:
	if type != TileCardType.INGREDIENT and type != TileCardType.MEAL:
		return ""
	var tag := GameTerms.format_ingredient_tags_label(ingredient_tags)
	if tag.is_empty():
		return ""
	var type_label := GameTerms.get_tile_card_type_label(self)
	if tag.to_lower() == type_label.to_lower():
		return ""
	return tag


func get_card_type_display() -> String:
	var type_label := GameTerms.get_tile_card_type_label(self)
	var tag := get_distinct_recipe_tag_label()
	if tag.is_empty():
		return type_label
	return "%s · %s" % [type_label, tag]


func _get_role_label() -> String:
	return GameTerms.get_role_label(product, support_role)


# Default chip: Ingredients show amount plus any station perk. Kitchenware shows flat Mult and role icon.
# Uses _effect_amount so chips stay honest when a card scales from the board.
func get_board_chip(tile: Hex = null) -> Dictionary:
	if is_producer_type(type):
		if product == Product.HYBRID or product == Product.NONE:
			return _hidden_board_chip()
		var base := _effect_amount(tile) + float(StationManager.flat_flavour_bonus_for(tile, self))
		var amount := base * StationManager.output_scale_for(tile, self) * star_output_scale()
		if amount <= 0.0:
			return _hidden_board_chip()
		if product == Product.MULTIPLIER:
			return _amount_board_chip_float(amount)
		return _amount_board_chip(int(round(amount)))
	return _stat_board_chip(tile)


func _stat_board_chip(tile: Hex = null) -> Dictionary:
	if type == TileCardType.KITCHENWARE and base_production_amount > 0:
		var mult := _get_production_amount() + KITCHENWARE_MULT_PER_PREP * float(get_planned_preparations(tile))
		var chip := _amount_board_chip_float(mult * star_output_scale(), ICON_MULT)
		var role_texture := FeastStatIcons.get_support_icon(support_role)
		if role_texture != null:
			chip = _compose_board_chip(chip, role_texture)
		return chip
	if support_role != SupportRole.NONE:
		return _support_role_chip(support_role)
	return _hidden_board_chip()


func _support_role_chip(role: SupportRole) -> Dictionary:
	var role_texture := FeastStatIcons.get_support_icon(role)
	if role_texture == null:
		return _hidden_board_chip()
	return _make_board_chip(BoardChipMode.AMOUNT, "", role_texture, CHIP_PANEL_COLOR)


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


## Station ×Mult chip. Uses an x prefix so it does not look like additive +Mult.
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
	var base_price := MEAL_SHOP_PRICE if type == TileCardType.MEAL else SHOP_PRICE
	return _apply_merchant_discount(base_price, discount)


# Empty spot, or an occupied spot to merge into or replace, plus placement restrictions.
func can_play_on(hex: Hex) -> bool:
	return get_overplay(hex) != Overplay.NONE


func is_placement_candidate(hex: Hex) -> bool:
	if hex.is_placement_blocked():
		return false
	return overplay_enabled or hex.active_tile_card == null


func get_overplay(hex: Hex) -> Overplay:
	if hex == null or hex.is_placement_blocked() or not can_place_on_tile(hex):
		return Overplay.NONE
	var occupant := hex.active_tile_card
	if occupant == null:
		return Overplay.PLACE
	if not overplay_enabled:
		return Overplay.NONE
	if occupant.id != id:
		# Replacing destroys the occupant, and a Ward forbids that.
		if CondimentManager.is_warded(occupant):
			return Overplay.NONE
		return Overplay.REPLACE
	if occupant.star_level < MAX_STAR_LEVEL:
		return Overplay.MERGE
	return Overplay.NONE


# Empty spot: place. Same card: merge up a star. Different card: destroy the occupant with no refund.
func play_on(hex: Hex, animate: bool = true) -> void:
	match get_overplay(hex):
		Overplay.PLACE:
			hex.place_tile_card(self, animate)
		Overplay.MERGE:
			CondimentBoardEffects.star_up_placed_at(hex)
		Overplay.REPLACE:
			CondimentBoardEffects.destroy_placed_at(hex, hex.active_tile_card)
			hex.place_tile_card(self, animate)


func star_output_scale() -> float:
	return 1.0 + STAR_SCALE_STEP * float(star_level - 1)


## Output scale from Garnish stacks. Each stack adds GARNISH_SCALE_PER_STACK (x1.75, x2.5, ...).
static func garnish_scale_for(stacks: int) -> float:
	return 1.0 + GARNISH_SCALE_PER_STACK * float(maxi(stacks, 0))


## xMult under an output scale: only the part above x1 is boosted. x2 at scale 1.75 is x2.75.
static func scale_multiplicative_mult(factor: float, scale: float) -> float:
	return 1.0 + (factor - 1.0) * scale


static func star_text(level: int) -> String:
	return "★%d" % level


# Entry point for spot card activation. Mainly called by Hex.apply_tile_card_activation()
func activate_tile_card(tile: Hex, activation_scale: float = 1.0) -> void:
	if not is_active:
		return

	run_trigger_count += 1
	GameManager.register_tile_card_activation(self)
	EventBus.tile_card_activated.emit(self)
	if tile.map != null:
		StationManager.before_card_triggers(tile, self)
		_before_trigger(tile)

	var output_scale := activation_scale
	_activation_was_garnished = garnish_stacks > 0
	_activation_garnish_scale = garnish_scale_for(garnish_stacks)
	output_scale *= _activation_garnish_scale
	if tile.map != null:
		output_scale *= GameManager.chef.output_scale_for(tile, self)
		output_scale *= StationManager.output_scale_for(tile, self)
	output_scale *= star_output_scale()
	if not is_equal_approx(pending_output_scale, 1.0):
		output_scale *= pending_output_scale
		pending_output_scale = 1.0

	_activation_output_scale = output_scale
	_activation_flat_bonus = StationManager.flat_flavour_bonus_for(tile, self)
	# Count this activation before the card resolves so "triggers so far" includes the current one.
	tile.map.record_segment_trigger_for_tile(tile)
	_on_activate_tile_card(tile)
	# A card that paid no Flavour this trigger still gets its station bonus, scaled the same way.
	if _activation_flat_bonus > 0:
		add_flavour(tile, 0)
	_play_trigger_sound()
	GameManager.chef.after_card_triggered(tile, self)
	CondimentManager.after_card_activated(tile, self)
	StaffManager.after_card_activated(tile, self)
	StationManager.after_card_triggered(tile, self)
	if _activation_was_garnished:
		# The Garnish keeps boosting this card's triggers until the Hour ends (end_hour_garnish).
		hour_was_garnished = true
	_activation_output_scale = 1.0
	_activation_garnish_scale = 1.0
	_activation_was_garnished = false
	_activation_flat_bonus = 0


## Runs at the start of each trigger, before Garnish and output scales are read, so a card can
## Garnish itself for this trigger (Grilled Steak). Does nothing by default.
func _before_trigger(_tile: Hex) -> void:
	pass


## Hour end. A Garnish that boosted this card this Hour spends one of its Hours (one, two with
## Preserving) and is used up when none are left. A Garnish that has not boosted anything yet waits.
func end_hour_garnish() -> void:
	if not hour_was_garnished or garnish_stacks <= 0:
		return
	garnish_hours_left -= 1
	if garnish_hours_left > 0:
		return
	garnish_stacks = 0
	garnish_hours_left = 0
	EventBus.tile_card_garnish_cleared.emit(self)

# Queue extra spot card activations to resolve before fire flow continues.
func queue_tile_card_triggers(source_tile: Hex, tile_cards: Array[TileCard], activation_scales: Array[float] = []) -> void:
	source_tile.map.queue_tile_card_triggers(tile_cards, activation_scales, source_tile)


## Queues only triggerable spot cards. Shows Failed when nothing valid can fire.
func _try_queue_tile_card_triggers(
	source_tile: Hex,
	tile_cards: Array[TileCard],
	activation_scales: Array[float] = [],
) -> bool:
	var triggerable: Array[TileCard] = []
	var aligned_scales: Array[float] = []
	for i in range(tile_cards.size()):
		var card := tile_cards[i]
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

	queue_tile_card_triggers(source_tile, triggerable, aligned_scales)
	return true


## Isolated RNG for this card's current activation. Same seed and same play replay.
func _effect_rng(tile: Hex, tag: String = "effect") -> RandomNumberGenerator:
	return RunRng.create_card_effect_rng(tile, self, tag)


# Placement validation used by CardPlacementHandler while a spot card is selected.
# Meals only go on the Meal slots at the end of a station. Every other card stays off them.
func can_place_on_tile(tile: Hex) -> bool:
	if tile == null or tile.map == null:
		return false
	return tile.map.is_meal_slot(tile.coordinates) == (type == TileCardType.MEAL)


# Spot coordinates that would be impacted when this card is placed on hover_tile.
# Override when the preview is not a placed-card list from _effect_preview_cards.
func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _effect_preview_cards(hover_tile))


## Seats that count toward this card's output. Meals override with the station cards they use.
func get_trigger_preview_gold_coords(_hover_tile: Hex) -> Array[Vector2i]:
	return []


#region --- Flavour, Gold, Mult, and floating text helpers ---
func add_flavour(tile: Hex, base_points: Variant) -> void:
	# The station's flat bonus joins the first Flavour payout's base, so every multiplier scales it.
	var base := float(base_points) + float(_activation_flat_bonus)
	_activation_flat_bonus = 0
	var points := int(round(base * _activation_output_scale))
	hour_flavour_produced += points
	tile.map.add_turn_flavour_for_tile(tile, points)
	_create_floating_text(tile, "+%d" % points, Color.AQUA, ICON_FLAVOUR, null, _payout_float_is_garnished())


func add_gold(tile: Hex, base_amount: Variant, scaled: bool = true) -> void:
	if not EventManager.can_gain_gold():
		return
	# Garnish does not scale Gold. Every other scale still does.
	var gold_scale := _activation_output_scale / _activation_garnish_scale
	var amount := int(round(float(base_amount) * (gold_scale if scaled else 1.0)))
	tile.map.add_turn_gold_for_tile(tile, amount)
	_create_floating_text(tile, "+%d" % amount, Color(1.0, 0.85, 0.2, 1.0), ICON_GOLD, null, false)

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
		_payout_float_is_garnished(scaled)
	)


func multiply_multiplicative_mult(tile: Hex, factor: Variant, scaled: bool = true) -> void:
	var amount := float(factor)
	if scaled:
		# Only the part above x1 is boosted, by the whole output scale (Garnish, stars, chef, Station).
		amount = scale_multiplicative_mult(amount, _activation_output_scale)
	tile.map.multiply_turn_multiplicative_mult_for_tile(tile, amount)
	_create_floating_text(
		tile,
		CountingNumber.format_multiplicative_mult(amount),
		Color.PLUM,
		ICON_MULT,
		null,
		_payout_float_is_garnished(scaled)
	)


func failed_tile_card_text(tile: Hex) -> void:
	_create_floating_text(tile, "Failed", Color.RED)


## False when this card only resolves from its own fire-order slot (single_activation_per_turn).
func can_be_triggered_by_other_card(_tile: Hex = null) -> bool:
	return not single_activation_per_turn


func _is_triggerable_tile_card(source_tile: Hex, tile_card: TileCard) -> bool:
	var board := _board(source_tile)
	if board == null or tile_card == null:
		return false
	return board.card_on_hex(board.get_hex_for_card(tile_card)) != null


## Adds one Garnish stack to a triggerable spot card, up to its stack cap.
## Returns how many stacks landed (0 when none did).
func _try_garnish_tile_card(source_tile: Hex, target: TileCard) -> int:
	if not _is_triggerable_tile_card(source_tile, target):
		return 0
	if not target.add_garnish():
		return 0
	var landed := 1
	# Staff can make a Kitchenware Garnish land more than once.
	if type == TileCardType.KITCHENWARE:
		for _i in StaffManager.extra_garnish_applications(source_tile, self, target):
			if target.add_garnish():
				landed += 1
	return landed


# Queues a newly created card for the hand reveal animation. Does not use tile_card_selected.
func _add_generated_card_to_hand(card: Card) -> void:
	EventBus.generated_hand_card.emit(card)


func _create_floating_text(
	tile: Hex,
	text: String,
	color: Color = Color.WHITE,
	text_icon: Texture2D = null,
	target_icon: Texture2D = null,
	garnished: bool = false
) -> void:
	var tile_pos := tile.map.floating_text_position_for_hex(tile.coordinates)
	tile.map.create_floating_text(tile_pos, text, color, text_icon, target_icon, garnished)


# True when this trigger had Garnish stacks and the payout was actually scaled.
func _payout_float_is_garnished(scaled: bool = true) -> bool:
	return scaled and _activation_was_garnished


## Kitchenware target feedback as [ability icon] [target card icon].
func _create_targeted_ability_floating_text(
	tile: Hex,
	ability_icon: Texture2D,
	target: TileCard
) -> void:
	if target.icon == null:
		return
	_create_floating_text(tile, "", Color.WHITE, ability_icon, target.icon)


## Kitchenware garnish feedback.
func _create_garnish_floating_text(tile: Hex, target: TileCard) -> void:
	_create_targeted_ability_floating_text(tile, ICON_GARNISH, target)


## Kitchenware fire feedback.
func _create_fired_floating_text(tile: Hex, target: TileCard) -> void:
	_create_targeted_ability_floating_text(tile, ICON_FIRE, target)


## Shared activation blip for every fire, including misses with no float text.
func _play_trigger_sound() -> void:
	if GameManager.skip_presentation:
		return
	AudioManager.play_card_trigger_chop()

#endregion --- Flavour, Gold, Mult, and floating text helpers ---

func _get_production_amount() -> float:
	return float(base_production_amount)


## Amount this card should pay and show. Override instead of duplicating chip and activate math.
func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount()


## Placed cards this effect cares about. Default preview maps these to coordinates.
func _effect_preview_cards(_tile: Hex) -> Array[TileCard]:
	return []


## Pays _effect_amount using this card's product. Silent when the amount is empty.
## Pass fail_if_empty to show Failed instead of paying nothing.
func _pay_effect_amount(tile: Hex, fail_if_empty: bool = false) -> bool:
	var amount := _effect_amount(tile)
	var paid := false
	match product:
		Product.FLAVOUR:
			if amount > 0.0:
				add_flavour(tile, amount)
				paid = true
		Product.MULTIPLIER:
			if not is_zero_approx(amount):
				add_additive_mult(tile, amount)
				paid = true
		Product.GOLD:
			if amount > 0.0:
				add_gold(tile, amount)
				paid = true
	if fail_if_empty and not paid:
		failed_tile_card_text(tile)
		return false
	return paid


## Adds one Garnish stack. Returns false when already at the stack cap.
func add_garnish() -> bool:
	if garnish_stacks >= StaffManager.max_garnish_stacks_for(self):
		return false

	if garnish_stacks <= 0:
		garnish_hours_left = 1 + StaffManager.extra_garnish_hours(self)
	garnish_stacks += 1
	EventBus.tile_card_garnished.emit(self)
	StaffManager.after_card_garnished(self)
	return true


## Clears Garnish stacks and any unspent one-shot scale. Runs at the end of the Day.
func clear_garnish() -> void:
	pending_output_scale = 1.0
	garnish_hours_left = 0
	if garnish_stacks <= 0:
		return

	garnish_stacks = 0
	EventBus.tile_card_garnish_cleared.emit(self)


## Hour end: unspent one-shot scale goes. A waiting Garnish stays until the card triggers.
func clear_hour_scale() -> void:
	pending_output_scale = 1.0

## Scale this seated card lends to another card on its station whenever that card fires.
## StationManager multiplies these into the activation scale and the board chip. Grape lifts Beverages.
func station_output_scale_for(_card: TileCard) -> float:
	return 1.0


## Scale this seated card lends to a card on the station on either side of its own.
## own_tile is this card's hex. StationManager reads it with station_output_scale_for. Vinaigrette lifts Salads.
func neighbour_station_output_scale_for(_card: TileCard, _own_tile: Hex) -> float:
	return 1.0


## Default fire. Override when the card does more than pay its product.
func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile)


## Kitchenware Mult: the flat amount printed on the card plus KITCHENWARE_MULT_PER_PREP for each
## Ingredient it prepared this trigger (each retrigger, Garnish stack or status counts). Paid after
## the card's ability so the count is known.
func _pay_kitchenware_mult(tile: Hex, prepared: int = 0) -> void:
	hour_prepared_count += maxi(prepared, 0)
	var amount := _get_production_amount() + KITCHENWARE_MULT_PER_PREP * float(maxi(prepared, 0))
	if amount > 0.0:
		add_additive_mult(tile, amount)


## Ingredients this Kitchenware would prepare if it triggered now. Board chips and fried Meal
## previews read it. Kitchenware scripts override it.
func get_planned_preparations(_tile: Hex) -> int:
	return 0


## Board-position statuses this seated Kitchenware lends (Seasoned, Blended, Passed). Called by
## HexBoardQuery.refresh_kitchenware_prep in fire order whenever a seat changes. See KitchenwarePrep.
func apply_board_prep(_tile: Hex, _board: HexBoardQuery) -> void:
	pass


## "Garnished if next to X" cards. Garnishes this card mid-activation so the current fire
## already pays the Garnish boost. Later fires this Hour read the stack as usual.
func _garnish_self_now() -> bool:
	if garnish_stacks > 0:
		return false
	if not add_garnish():
		return false
	var boost := garnish_scale_for(garnish_stacks)
	_activation_output_scale *= boost
	_activation_garnish_scale *= boost
	_activation_was_garnished = true
	return true


## Garnishes each target that can take another stack, floating the Garnish icon for each.
## Shows Failed when none of them took it. Returns the Garnish stacks that landed, which
## Whisk and Kitchen Torch count as prepared Ingredients for their Mult.
func _garnish_targets(tile: Hex, targets: Array[TileCard]) -> int:
	var landed := 0
	for target: TileCard in targets:
		var stacks := _try_garnish_tile_card(tile, target)
		if stacks > 0:
			_create_garnish_floating_text(tile, target)
			landed += stacks
	if landed <= 0:
		failed_tile_card_text(tile)
	return landed


## Stacks a one-shot output scale on a later card (unused since Skillet and Deep Fryer became retriggers).
func _try_scale_tile_card(source_tile: Hex, target: TileCard, factor: float) -> bool:
	if not _is_triggerable_tile_card(source_tile, target):
		return false
	target.pending_output_scale *= factor
	return true


#region --- Map query helpers ---
## Indexed board lookups for this activation. Null when the hex is not on a live map.
func _board(tile: Hex) -> HexBoardQuery:
	if tile == null or tile.map == null:
		return null
	return tile.map.query


func _get_all_placed_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.placed_cards(filter_type)


func _get_all_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.adjacent_cards(tile, filter_type)


func _get_next_tile_cards_in_trigger_order(
	tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.cards_relative_to_trigger_order(tile, count, false, filter_type)


## Fire-order seats right before this one.
func _get_immediately_previous_hexes(tile: Hex, count: int) -> Array[Hex]:
	var board := _board(tile)
	if board == null:
		return []
	return board.immediately_previous_hexes(tile, count)


func _get_tile_cards_on_immediately_previous_hexes(tile: Hex, count: int) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for hex: Hex in _get_immediately_previous_hexes(tile, count):
		if hex.active_tile_card == null:
			continue
		result.append(hex.active_tile_card)
	return result


## Clears Hour Flavour and Mult snapshots before this Hour's fire order starts.
func reset_hour_product_snapshot() -> void:
	hour_was_garnished = false
	hour_prepared_count = 0
	hour_flavour_produced = 0
	hour_additive_mult_produced = 0.0


func _get_segment_index(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return -1
	return tile.map.get_segment_index(tile.coordinates)


func _get_segment_count(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return 0
	return tile.map.get_segment_count()


func _get_next_segment_index(tile: Hex) -> int:
	var next_segment_index := _get_segment_index(tile) + 1
	if next_segment_index < 0 or next_segment_index >= _get_segment_count(tile):
		return -1
	return next_segment_index


func _get_all_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.cards_on_same_segment(tile, filter_type)


func _get_segment_trigger_count_this_turn(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return 0
	return tile.map.get_segment_turn_trigger_count(_get_segment_index(tile))


func _cards_by_kind(tile: Hex, filter_kind: Variant, scope: QueryScope) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.cards_by_kind(tile, filter_kind, scope)


func _filter_tile_cards_by_kind(cards: Array[TileCard], filter_kind: Variant) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card: TileCard in cards:
		if matches_kind_filter(card, filter_kind):
			result.append(card)
	return result


func _coords_for_placed_tile_cards(tile: Hex, tile_cards: Array[TileCard]) -> Array[Vector2i]:
	var board := _board(tile)
	if board == null:
		return []
	return board.coords_for_cards(tile_cards)


func _coords_for_cards_by_kind(tile: Hex, filter_kind: Variant, scope: QueryScope) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _cards_by_kind(tile, filter_kind, scope))


func _hex_for(tile: Hex, card: TileCard) -> Hex:
	var board := _board(tile)
	if board == null:
		return null
	return board.get_hex_for_card(card)

#endregion --- Map query helpers ---


## Destroy a placed card. Returns false when a Ward saved it.
func _destroy_placed_tile_card(source_tile: Hex, tile_card: TileCard) -> bool:
	return CondimentBoardEffects.destroy_placed_at(source_tile, tile_card)


## Destroy a placed card after its queued chained triggers finish resolving.
## on_done receives false when a Ward saved the card.
func _destroy_placed_tile_card_after_queued_triggers(
	source_tile: Hex,
	tile_card: TileCard,
	on_done: Callable = Callable(),
) -> void:
	var destroy := func() -> void:
		var destroyed := _destroy_placed_tile_card(source_tile, tile_card)
		if on_done.is_valid():
			on_done.call(destroyed)
	source_tile.map.run_after_trigger_link(source_tile, destroy)
#endregion --- Spot card destruction helpers ---
