class_name MealCard
extends TileCard

## Seated plate. Reads the N spots immediately before it in fire order, never the whole station.
## Those seats are a bag of tags. Empty or wrong cards break the dish. No skipping gaps.
## On a match, this card plates a local meal pile. Some dishes also write station ×Mult.

## Dish recipe bag. Prefix length is the sum of these counts.
@export var recipe_vegetable_count: int = 0
@export var recipe_fruit_count: int = 0
@export var recipe_grain_count: int = 0
@export var recipe_protein_count: int = 0
@export var recipe_seasoning_count: int = 0
@export var recipe_kitchenware_count: int = 0

## A Kitchenware recipe slot is matched by card type, not by an authored ingredient tag.

## Last prefix resolve for this instance. Cleared at each public chip, inspect, or fire.
var _prefix_memo_tile: Hex = null
var _prefix_memo: Dictionary = {}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_immediately_previous_hexes(hover_tile, get_effective_prefix_size())


## Prefix seats holding a card whose tag this dish can use. Gold even if the bag is incomplete.
func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _prefix_preview_coords(hover_tile, true)


## Occupied prefix seats whose tags cannot fill this dish's recipe.
func get_trigger_preview_invalid_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _prefix_preview_coords(hover_tile, false)


func _prefix_preview_coords(hover_tile: Hex, matching: bool) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for hex: Hex in _get_immediately_previous_hexes(hover_tile, get_effective_prefix_size()):
		if hex.active_tile_card == null:
			continue
		if card_matches_needed_tag(hex.active_tile_card) == matching:
			coords.append(hex.coordinates)
	return coords


## True when this card's tag could fill at least one slot in the recipe bag.
func card_matches_needed_tag(card: TileCard) -> bool:
	if card == null or get_recipe_prefix_size() <= 0:
		return false
	if recipe_kitchenware_count > 0 and card.type == TileCardType.KITCHENWARE:
		return true
	var remaining := _recipe_slot_counts()
	return not _compatible_recipe_slots(card, remaining).is_empty()


func get_board_chip(tile: Hex = null) -> Dictionary:
	_clear_prefix_memo()
	if tile == null:
		return _stat_board_chip()
	var plated := _compute_plated_outputs(tile)
	if plated.is_empty():
		return _stat_board_chip()
	var flavour := int(plated.get("flavour", 0))
	var additive_mult := float(plated.get("additive_mult", 0.0))
	var multiplicative_mult := float(plated.get("multiplicative_mult", 0.0))
	var has_flavour := flavour > 0
	var has_mult := not is_zero_approx(additive_mult)
	var has_xmult := not is_zero_approx(multiplicative_mult)
	if not has_flavour and not has_mult and not has_xmult:
		return _stat_board_chip()
	if has_flavour and has_mult:
		return _dual_amount_board_chip(flavour, additive_mult)
	if has_flavour and has_xmult:
		var chip := _amount_board_chip(flavour, ICON_FLAVOUR)
		chip["extra_text"] = CountingNumber.format_multiplicative_mult(multiplicative_mult)
		chip["extra_icon"] = ICON_MULT
		chip["extra_amount"] = multiplicative_mult
		return chip
	if has_mult:
		return _amount_board_chip_float(additive_mult, ICON_MULT)
	if has_xmult:
		return _multiplicative_mult_board_chip(multiplicative_mult)
	return _amount_board_chip(flavour, ICON_FLAVOUR)


func _on_activate_tile_card(tile: Hex) -> void:
	_clear_prefix_memo()
	var recipe := get_matched_prefix_recipe(tile)
	if get_recipe_prefix_size() > 0 and recipe.is_empty():
		failed_tile_card_text(tile)
		return
	var flavour := _plated_flavour_from_recipe(recipe)
	var additive_mult := _plated_additive_mult_from_recipe(recipe)
	var multiplicative_mult := _plated_multiplicative_mult_from_recipe(recipe)
	if flavour > 0:
		add_flavour(tile, flavour)
	if not is_zero_approx(additive_mult):
		add_additive_mult(tile, additive_mult)
	if not is_zero_approx(multiplicative_mult):
		multiply_multiplicative_mult(tile, multiplicative_mult)
	if flavour <= 0 and is_zero_approx(additive_mult) and is_zero_approx(multiplicative_mult):
		failed_tile_card_text(tile)
		return
	RunLedger.record_dish_plated()
	# Plated short of the full recipe, so a chef waived the missing ingredient.
	if recipe.size() < get_recipe_prefix_size():
		ChefManager.notify_dish_discount_used(tile)


## Empty when the prefix recipe is incomplete.
func _compute_plated_outputs(tile: Hex) -> Dictionary:
	if get_recipe_prefix_size() > 0 and _resolved_prefix(tile).is_empty():
		return {}
	return {
		"flavour": _preview_plated_flavour(tile),
		"additive_mult": _preview_plated_additive_mult(tile),
		"multiplicative_mult": _preview_plated_multiplicative_mult(tile),
	}


## Snapshot pay. Prefix cards have already fired when the dish activates.
func _plated_flavour_from_recipe(_recipe: Array[TileCard]) -> int:
	return 0


func _plated_additive_mult_from_recipe(_recipe: Array[TileCard]) -> float:
	return 0.0


func _plated_multiplicative_mult_from_recipe(_recipe: Array[TileCard]) -> float:
	return 0.0


## Chip estimate. Uses Hour snapshots after those cards fire, otherwise their board chips.
func _preview_plated_flavour(tile: Hex) -> int:
	var recipe := get_matched_prefix_recipe(tile)
	if get_recipe_prefix_size() > 0 and recipe.is_empty():
		return 0
	return _plated_flavour_from_recipe(recipe)


func _preview_plated_additive_mult(tile: Hex) -> float:
	var recipe := get_matched_prefix_recipe(tile)
	if get_recipe_prefix_size() > 0 and recipe.is_empty():
		return 0.0
	return _plated_additive_mult_from_recipe(recipe)


func _preview_plated_multiplicative_mult(tile: Hex) -> float:
	var recipe := get_matched_prefix_recipe(tile)
	if get_recipe_prefix_size() > 0 and recipe.is_empty():
		return 0.0
	return _plated_multiplicative_mult_from_recipe(recipe)


## Slots in the full recipe bag, before any chef discount.
func get_recipe_prefix_size() -> int:
	return (
		recipe_vegetable_count
		+ recipe_fruit_count
		+ recipe_grain_count
		+ recipe_protein_count
		+ recipe_seasoning_count
		+ recipe_kitchenware_count
	)


## Ingredient slots chefs let this dish leave empty. Kitchenware slots are never waived,
## and at least one seat always has to be filled.
func get_waived_ingredient_slots() -> int:
	var prefix_size := get_recipe_prefix_size()
	var ingredient_slots := prefix_size - recipe_kitchenware_count
	var max_waived := maxi(mini(ingredient_slots, prefix_size - 1), 0)
	return clampi(ChefManager.dish_ingredient_discount(), 0, max_waived)


## How many fire-order seats this dish reads immediately before itself right now.
func get_effective_prefix_size() -> int:
	return get_recipe_prefix_size() - get_waived_ingredient_slots()


## True when this dish has no prefix bag, or the fire-order prefix currently matches.
func is_recipe_ready(tile: Hex) -> bool:
	if get_recipe_prefix_size() <= 0:
		return true
	return not get_matched_prefix_recipe(tile).is_empty()


## Inspect copy for the hover panel. Bag first, then whether this seat's prefix matches.
func get_inspect_recipe_text(tile: Hex = null) -> String:
	_clear_prefix_memo()
	var bag := _recipe_bag_text()
	if bag.is_empty():
		return ""
	var waived := get_waived_ingredient_slots()
	if waived > 0:
		bag = "%s (any %d Ingredient optional)" % [bag, waived]
	if tile == null or tile.map == null:
		return "Recipe: %s" % bag
	if not is_recipe_ready(tile):
		return "Recipe: %s\nPrefix incomplete" % bag
	return "Recipe: %s\nPrefix ready" % bag


func _recipe_bag_text() -> String:
	var parts: PackedStringArray = []
	_append_recipe_part(parts, recipe_vegetable_count, GameTerms.VEGETABLE)
	_append_recipe_part(parts, recipe_fruit_count, GameTerms.FRUIT)
	_append_recipe_part(parts, recipe_grain_count, GameTerms.GRAIN)
	_append_recipe_part(parts, recipe_protein_count, GameTerms.PROTEIN)
	_append_recipe_part(parts, recipe_seasoning_count, GameTerms.SEASONING)
	_append_recipe_part(parts, recipe_kitchenware_count, GameTerms.KITCHENWARE)
	return ", ".join(parts)


func _append_recipe_part(parts: PackedStringArray, count: int, tag: String) -> void:
	if count <= 0:
		return
	if count == 1:
		parts.append("1 %s" % tag)
		return
	var plural := tag
	if tag != GameTerms.KITCHENWARE:
		plural = "%ss" % tag
	parts.append("%d %s" % [count, plural])


## Prefix cards when every required seat is filled and the tag bag matches. Empty on fail.
func get_matched_prefix_recipe(tile: Hex) -> Array[TileCard]:
	var resolved := _resolved_prefix(tile)
	if resolved.is_empty():
		var empty: Array[TileCard] = []
		return empty
	var cards: Array[TileCard] = resolved["cards"]
	return cards


func _clear_prefix_memo() -> void:
	_prefix_memo_tile = null
	_prefix_memo = {}


## Occupied prefix plus slot assignment. Memoized for one chip, inspect, or fire call.
func _resolved_prefix(tile: Hex) -> Dictionary:
	if tile == _prefix_memo_tile:
		return _prefix_memo
	_prefix_memo_tile = tile
	_prefix_memo = _compute_resolved_prefix(tile)
	return _prefix_memo


func _compute_resolved_prefix(tile: Hex) -> Dictionary:
	var cards := _prefix_recipe_cards(tile)
	if cards.is_empty():
		return {}
	var assigned := _assign_recipe_slots(cards)
	if assigned.is_empty():
		return {}
	return {
		"cards": cards,
		"assigned": assigned,
		"hexes": _get_immediately_previous_hexes(tile, cards.size()),
	}


func _recipe_slot_counts() -> Dictionary:
	return {
		TAG_VEGETABLE: recipe_vegetable_count,
		TAG_FRUIT: recipe_fruit_count,
		TAG_GRAIN: recipe_grain_count,
		TAG_PROTEIN: recipe_protein_count,
		TAG_SEASONING: recipe_seasoning_count,
		TAG_KITCHENWARE: recipe_kitchenware_count,
	}


## Occupied prefix cards in fire-order seats. Empty when a seat is missing or unoccupied.
func _prefix_recipe_cards(tile: Hex) -> Array[TileCard]:
	var prefix_size := get_effective_prefix_size()
	var cards: Array[TileCard] = []
	if tile == null or tile.map == null or prefix_size <= 0:
		return cards
	var hexes := _get_immediately_previous_hexes(tile, prefix_size)
	if hexes.size() != prefix_size:
		return cards
	for hex: Hex in hexes:
		if hex.active_tile_card == null:
			return []
		cards.append(hex.active_tile_card)
	return cards


## Each prefix card claims at most one bag slot. Dual-tagged cards take the scarcest remaining slot.
## Empty dictionary means the bag cannot be filled. Chefs may waive leftover ingredient slots.
func _assign_recipe_slots(cards: Array[TileCard]) -> Dictionary:
	var remaining := {}
	var slot_counts := _recipe_slot_counts()
	for tag: StringName in slot_counts:
		var count := int(slot_counts[tag])
		if count > 0:
			remaining[tag] = count
	var assigned := {}
	var pending: Array[TileCard] = cards.duplicate()
	while not pending.is_empty():
		var best_index := -1
		var best_slots: Array[StringName] = []
		for i in range(pending.size()):
			var slots := _compatible_recipe_slots(pending[i], remaining)
			if slots.is_empty():
				return {}
			if best_index < 0 or slots.size() < best_slots.size():
				best_index = i
				best_slots = slots
		var chosen := _rarest_remaining_slot(best_slots, remaining)
		if chosen == &"":
			return {}
		assigned[pending[best_index]] = chosen
		remaining[chosen] = int(remaining[chosen]) - 1
		if int(remaining[chosen]) <= 0:
			remaining.erase(chosen)
		pending.remove_at(best_index)
	if not _unfilled_slots_are_waived(remaining):
		return {}
	return assigned


func _unfilled_slots_are_waived(remaining: Dictionary) -> bool:
	if remaining.is_empty():
		return true
	if remaining.has(TAG_KITCHENWARE):
		return false
	var unfilled := 0
	for tag: StringName in remaining:
		unfilled += int(remaining[tag])
	return unfilled <= get_waived_ingredient_slots()


func _compatible_recipe_slots(card: TileCard, remaining: Dictionary) -> Array[StringName]:
	var slots: Array[StringName] = []
	if card == null:
		return slots
	if card.type == TileCardType.KITCHENWARE:
		if int(remaining.get(TAG_KITCHENWARE, 0)) > 0:
			slots.append(TAG_KITCHENWARE)
		return slots
	for tag: StringName in RECIPE_INGREDIENT_TAGS:
		if int(remaining.get(tag, 0)) <= 0:
			continue
		if card.has_ingredient_tag(tag):
			slots.append(tag)
	return slots


func _rarest_remaining_slot(slots: Array[StringName], remaining: Dictionary) -> StringName:
	var chosen := &""
	var chosen_left := 0
	for tag: StringName in slots:
		var left := int(remaining.get(tag, 0))
		if left <= 0:
			continue
		if chosen == &"" or left < chosen_left:
			chosen = tag
			chosen_left = left
	return chosen


func _recipe_bag_matches(cards: Array[TileCard]) -> bool:
	return not _assign_recipe_slots(cards).is_empty()


func _sum_hour_flavour_for_kind(cards: Array[TileCard], kind: StringName) -> int:
	var total := 0
	for card: TileCard in _cards_assigned_to_kind(cards, kind):
		total += card.hour_flavour_produced
	return total


func _sum_hour_additive_mult_for_kind(cards: Array[TileCard], kind: StringName) -> float:
	var total := 0.0
	for card: TileCard in _cards_assigned_to_kind(cards, kind):
		total += card.hour_additive_mult_produced
	return total


func _cards_assigned_to_kind(cards: Array[TileCard], kind: StringName) -> Array[TileCard]:
	var matched: Array[TileCard] = []
	var assigned := _assignment_for_cards(cards)
	if assigned.is_empty():
		return matched
	for card: TileCard in cards:
		if assigned.get(card, &"") != kind:
			continue
		matched.append(card)
	return matched


## Reuses the memo assignment when these are the same prefix cards just resolved.
func _assignment_for_cards(cards: Array[TileCard]) -> Dictionary:
	if _prefix_memo.has("cards") and _prefix_memo["cards"] == cards:
		return _prefix_memo.get("assigned", {})
	return _assign_recipe_slots(cards)


## Flavour this prefix card will pay. Hour snapshot after it fires, otherwise its chip.
func _expected_flavour_from_card(card: TileCard, hex: Hex) -> int:
	if card == null:
		return 0
	if card.hour_flavour_produced != 0:
		return card.hour_flavour_produced
	if card.product != Product.FLAVOUR:
		return 0
	return int(round(_chip_amount(card, hex, card._get_production_amount())))


func _expected_additive_mult_from_card(card: TileCard, hex: Hex) -> float:
	if card == null:
		return 0.0
	if not is_zero_approx(card.hour_additive_mult_produced):
		return card.hour_additive_mult_produced
	if card.product != Product.MULTIPLIER:
		return 0.0
	return _chip_amount(card, hex, card._get_production_amount())


func _chip_amount(card: TileCard, hex: Hex, fallback: float) -> float:
	var chip: Dictionary = card.get_board_chip(hex)
	if int(chip.get("mode", BoardChipMode.HIDDEN)) == BoardChipMode.HIDDEN:
		return fallback
	var amount := float(chip.get("amount", 0.0))
	if amount != 0.0:
		return amount
	return fallback


func _sum_expected_flavour_for_kind(tile: Hex, kind: StringName) -> int:
	var resolved := _resolved_prefix(tile)
	if resolved.is_empty():
		return 0
	var cards: Array[TileCard] = resolved["cards"]
	var assigned: Dictionary = resolved["assigned"]
	var hexes: Array = resolved["hexes"]
	var total := 0
	for i in range(cards.size()):
		if assigned.get(cards[i], &"") != kind:
			continue
		total += _expected_flavour_from_card(cards[i], hexes[i])
	return total


func _sum_expected_additive_mult_for_kind(tile: Hex, kind: StringName) -> float:
	var resolved := _resolved_prefix(tile)
	if resolved.is_empty():
		return 0.0
	var cards: Array[TileCard] = resolved["cards"]
	var assigned: Dictionary = resolved["assigned"]
	var hexes: Array = resolved["hexes"]
	var total := 0.0
	for i in range(cards.size()):
		if assigned.get(cards[i], &"") != kind:
			continue
		total += _expected_additive_mult_from_card(cards[i], hexes[i])
	return total
