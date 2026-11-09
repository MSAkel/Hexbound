class_name MealCard
extends TileCard

## Seated in a Meal slot at the end of a station. Its requirements count the cards on that
## station's regular spots. A served Meal pays its own output and counts toward the station's level.
## Serving itself pays no Gold; only Meals whose own text says so do. A Meal whose requirements are missing shows Failed.
## Subclasses describe their output in _meal_outputs so the chip and the payout share one formula.

const DEEP_FRYER_ID := "deep_fryer"

## Menu category, named after the Meal's main ingredient or course. Separate from ingredient_tags
## on purpose. Kind queries such as "per Meat on the station" read those tags and count Meals too,
## so tagging a Meal as Meat would change balance. Values are saved in .tres files as ints, so
## append new categories at the end and never reorder.
enum MealCategory {
	NONE = 0,
	MEAT = 1,
	POULTRY = 2,
	SEAFOOD = 3,
	SALAD = 4,
	DESSERT = 5,
	SIDE = 6,
	SAUCE = 7,
	BEVERAGE = 8,
}

@export var meal_category: MealCategory = MealCategory.NONE

## Station requirements, counted across the station's regular spots (plus Passed Ingredients).
@export var recipe_vegetable_count: int = 0
@export var recipe_fruit_count: int = 0
@export var recipe_meat_count: int = 0
@export var recipe_seafood_count: int = 0
@export var recipe_dairy_count: int = 0
@export var recipe_sweet_count: int = 0
@export var recipe_seasoning_count: int = 0
## No Meal asks for Kitchenware since Kitchenware left recipes (Nov 2026). Kept so old content loads.
@export var recipe_kitchenware_count: int = 0
## Specific cards that must sit on the station, by id. Wine needs Grape.
@export var recipe_required_card_ids: Array[String] = []


## Card faces and the inspect panel show the category, such as Meal · Seafood, instead of the
## Dish or Beverage tag. Falls back to the tags when no category is set.
func get_distinct_recipe_tag_label() -> String:
	var label := GameTerms.get_meal_category_label(meal_category)
	if label.is_empty():
		return super.get_distinct_recipe_tag_label()
	return label


## A Station can't hold the same Meal in both of its Meal slots (Nov 2026, untuned). Merging onto
## the same Meal in this slot is still allowed, since it adds no second copy.
func can_place_on_tile(tile: Hex) -> bool:
	if not super.can_place_on_tile(tile):
		return false
	return not is_repeat_on_station(tile)


## True when the station's other Meal slot already holds this Meal. A card being moved (swapped)
## is ignored, so it doesn't block itself.
func is_repeat_on_station(tile: Hex) -> bool:
	if tile == null or tile.map == null or not tile.map.is_meal_slot(tile.coordinates):
		return false
	var seated_here := tile.active_tile_card
	if seated_here != null and seated_here != self and seated_here.id == id:
		return false
	var segment := tile.map.get_segment_index(tile.coordinates)
	if segment < 0:
		return false
	for coords: Vector2i in tile.map.get_meal_slot_coords(segment):
		if coords == tile.coordinates or not tile.map.map_data.has(coords):
			continue
		var other: Hex = tile.map.map_data[coords]
		var seated := other.active_tile_card
		if seated != null and seated != self and seated.id == id:
			return true
	return false


## What one fire of this Meal produces. multiplicative_mult of 1.0 means none.
class Output:
	var flavour := 0
	var additive_mult := 0.0
	var multiplicative_mult := 1.0

	func has_additive_mult() -> bool:
		return not is_zero_approx(additive_mult)

	func has_multiplicative_mult() -> bool:
		return not is_equal_approx(multiplicative_mult, 1.0) and not is_zero_approx(multiplicative_mult)


func _on_activate_tile_card(tile: Hex) -> void:
	if not is_recipe_ready(tile):
		failed_tile_card_text(tile)
		EventBus.meal_fired.emit(self, false)
		return
	EventBus.meal_fired.emit(self, true)
	# activate_tile_card already folded station perks into this fire's output scale.
	var output := _read_output(tile, false, 1.0)
	if output.flavour > 0:
		add_flavour(tile, output.flavour)
	if output.has_additive_mult():
		add_additive_mult(tile, output.additive_mult)
	if output.has_multiplicative_mult():
		multiply_multiplicative_mult(tile, output.multiplicative_mult)
	_serve(tile)


## Meal output for this fire. preview is true for chips, false when paying.
## Keys: flavour (int), additive_mult (float), multiplicative_mult (float, 1.0 = none).
func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {}


## _meal_outputs as an Output. scale multiplies Flavour and +Mult, the way an activation scale does.
## On xMult it boosts only the part above x1, matching multiply_multiplicative_mult.
## star_scale joins scale: stars follow the same rule.
func _read_output(tile: Hex, preview: bool, scale: float, star_scale: float = 1.0) -> Output:
	var raw := _meal_outputs(tile, preview)
	var total_scale := scale * star_scale
	var output := Output.new()
	output.flavour = int(round(float(raw.get("flavour", 0)) * total_scale))
	# The chef's Meal bonus (Pitmaster) joins the Meal's own +Mult before every multiplier.
	var additive := float(raw.get("additive_mult", 0.0)) + GameManager.chef.meal_extra_mult(tile, self)
	output.additive_mult = additive * total_scale
	output.multiplicative_mult = float(raw.get("multiplicative_mult", 1.0))
	if output.has_multiplicative_mult():
		output.multiplicative_mult = scale_multiplicative_mult(output.multiplicative_mult, total_scale)
	return output


## Every served Meal adds a serving for its station. Gold only comes from a Meal's own effect.
func _serve(tile: Hex) -> void:
	RunLedger.record_dish_plated()
	if _missing_ingredient_count(tile) > 0:
		StaffManager.notify_dish_discount_used(tile)
	StationManager.record_serving(_get_segment_index(tile))
	StationManager.on_meal_served(tile, self)
	GameManager.chef.on_meal_served(tile, self)
	StaffManager.after_meal_served(tile, self)


## Meal Gold goes straight to the total. No float or sound on the Meal itself.
func _add_quiet_gold(tile: Hex, amount: int) -> void:
	if tile != null and tile.map != null:
		tile.map.add_turn_gold_for_tile(tile, amount)


## Primary number is Flavour, else Mult. One extra slot shows Mult or xMult beside it.
func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile != null and tile.map != null and not is_recipe_ready(tile):
		return _hidden_board_chip()
	# Idle in a locked second slot. It pays nothing until the station is level 3 again.
	if tile != null and StationManager.is_meal_slot_locked(tile.coordinates):
		return _hidden_board_chip()
	var output := _read_output(tile, true, StationManager.output_scale_for(tile, self), star_output_scale())
	var chip: Dictionary
	if output.flavour > 0:
		chip = _amount_board_chip(output.flavour, ICON_FLAVOUR)
		if output.has_additive_mult():
			return _with_mult_extra(chip, CountingNumber.format_additive_mult(output.additive_mult), output.additive_mult)
	elif output.has_additive_mult():
		chip = _amount_board_chip_float(output.additive_mult, ICON_MULT)
	elif output.has_multiplicative_mult():
		return _multiplicative_mult_board_chip(output.multiplicative_mult)
	else:
		return _hidden_board_chip()
	if output.has_multiplicative_mult():
		var xmult_text := CountingNumber.format_multiplicative_mult(output.multiplicative_mult)
		return _with_mult_extra(chip, xmult_text, output.multiplicative_mult)
	return chip


func _with_mult_extra(chip: Dictionary, text: String, amount: float) -> Dictionary:
	chip["extra_text"] = text
	chip["extra_icon"] = ICON_MULT
	chip["extra_amount"] = amount
	return chip


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return get_trigger_preview_gold_coords(hover_tile)


## Station cards this Meal's requirements can use.
func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _matching_station_cards(hover_tile))


#region --- Requirements ---
## True when this Meal would be served if it fired now. Its requirements are met and it is not
## idle in a locked second Meal slot. A Failed or idle Meal does not count.
func is_serving(tile: Hex) -> bool:
	if tile == null or tile.map == null:
		return false
	if StationManager.is_meal_slot_locked(tile.coordinates):
		return false
	return is_recipe_ready(tile)


## Number of cards the requirements ask for, before any staff discount.
func get_recipe_size() -> int:
	var total := recipe_required_card_ids.size()
	for count: int in _recipe_slot_counts().values():
		total += count
	return total


## Ingredient requirements staff let this Meal skip. Kitchenware and named cards are never waived.
func get_waived_ingredient_slots() -> int:
	var ingredient_slots := get_recipe_size() - recipe_kitchenware_count - recipe_required_card_ids.size()
	return clampi(StaffManager.dish_ingredient_discount(), 0, maxi(ingredient_slots, 0))


## True when the station holds everything this Meal asks for.
func is_recipe_ready(tile: Hex) -> bool:
	if get_recipe_size() <= 0:
		return true
	if tile == null or tile.map == null:
		return false
	var cards := _station_cards(tile)
	for card_id: String in recipe_required_card_ids:
		if not cards.any(func(card: TileCard) -> bool: return card.id == card_id):
			return false
	if _missing_for_tag(cards, TAG_KITCHENWARE) > 0:
		return false
	return _missing_ingredient_count(tile) <= get_waived_ingredient_slots()


## Cards the station still needs before this Meal is ready. 0 means ready.
func get_missing_card_count(tile: Hex) -> int:
	if get_recipe_size() <= 0:
		return 0
	if tile == null or tile.map == null:
		return get_recipe_size()
	var cards := _station_cards(tile)
	var missing := 0
	for card_id: String in recipe_required_card_ids:
		if not cards.any(func(card: TileCard) -> bool: return card.id == card_id):
			missing += 1
	missing += _missing_for_tag(cards, TAG_KITCHENWARE)
	missing += maxi(0, _missing_ingredient_count(tile) - get_waived_ingredient_slots())
	return missing


## Inspect copy for the hover panel. Lists the requirements only.
func get_inspect_recipe_text(_tile: Hex = null) -> String:
	var bag := _recipe_bag_text()
	if bag.is_empty():
		return ""
	var waived := get_waived_ingredient_slots()
	if waived > 0:
		bag = "%s (any %d Ingredient optional)" % [bag, waived]
	return "Requires: %s" % bag


## One entry per required card, in inspect text order. Keys: icon (Texture2D), kind (StringName,
## empty for a named card). A count of 2 lists the kind twice.
func get_requirement_icons() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for card_id: String in recipe_required_card_ids:
		var template := GameManager.get_tile_card_by_id(card_id)
		var icon_texture: Texture2D = template.icon if template != null and template.icon != null else FeastStatIcons.PLACEHOLDER
		entries.append({"icon": icon_texture, "kind": &""})
	var counts := _recipe_slot_counts()
	for tag: StringName in counts:
		for _i in int(counts[tag]):
			entries.append({"icon": FeastStatIcons.get_ingredient_kind_icon(tag), "kind": tag})
	return entries


## Cards on this Meal's station regular spots, plus Ingredients a Cutting Board on the station
## above passed down to it (Passed). Requirements and "for each" effects read these.
## Meals never fill requirements.
func _station_cards(tile: Hex) -> Array[TileCard]:
	var cards := _own_station_cards(tile)
	cards.append_array(_passed_in_cards(tile))
	return cards


## Cards seated on this Meal's station regular spots only. Flavour reads use these, since a
## Passed Ingredient counts on this station but does not pay its Flavour here.
func _own_station_cards(tile: Hex) -> Array[TileCard]:
	if tile == null or tile.map == null:
		return []
	return tile.map.get_regular_tile_cards(_get_segment_index(tile))


## Ingredients passed down to this Meal's station by a Cutting Board on the station above.
func _passed_in_cards(tile: Hex) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.passed_into_segment(_get_segment_index(tile))


func _matching_station_cards(tile: Hex) -> Array[TileCard]:
	var matching: Array[TileCard] = []
	var counts := _recipe_slot_counts()
	for card: TileCard in _station_cards(tile):
		if card.id in recipe_required_card_ids:
			matching.append(card)
			continue
		for tag: StringName in counts:
			if int(counts[tag]) > 0 and matches_kind_filter(card, tag):
				matching.append(card)
				break
	return matching


func _recipe_slot_counts() -> Dictionary:
	return {
		TAG_VEGETABLE: recipe_vegetable_count,
		TAG_FRUIT: recipe_fruit_count,
		TAG_MEAT: recipe_meat_count,
		TAG_SEAFOOD: recipe_seafood_count,
		TAG_DAIRY: recipe_dairy_count,
		TAG_SWEET: recipe_sweet_count,
		TAG_SEASONING: recipe_seasoning_count,
		TAG_KITCHENWARE: recipe_kitchenware_count,
	}


func _missing_for_tag(cards: Array[TileCard], tag: StringName) -> int:
	var needed := int(_recipe_slot_counts().get(tag, 0))
	if needed <= 0:
		return 0
	return maxi(needed - _filter_tile_cards_by_kind(_cards_left_for_kind_slots(cards), tag).size(), 0)


## Station cards minus one copy of each named requirement. A named card fills its own slot only,
## so Chocolate Cake (Chocolate + any Sweet) needs a second Sweet beside the Chocolate.
func _cards_left_for_kind_slots(cards: Array[TileCard]) -> Array[TileCard]:
	if recipe_required_card_ids.is_empty():
		return cards
	var left: Array[TileCard] = cards.duplicate()
	for card_id: String in recipe_required_card_ids:
		for i in left.size():
			if left[i].id == card_id:
				left.remove_at(i)
				break
	return left


## Ingredient requirements the station does not cover. Staff discounts can waive these.
func _missing_ingredient_count(tile: Hex) -> int:
	var cards := _station_cards(tile)
	var missing := 0
	for tag: StringName in RECIPE_INGREDIENT_TAGS:
		missing += _missing_for_tag(cards, tag)
	return missing


func _recipe_bag_text() -> String:
	var parts: PackedStringArray = []
	for card_id: String in recipe_required_card_ids:
		var template := GameManager.get_tile_card_by_id(card_id)
		parts.append(template.name if template != null else card_id.capitalize())
	var counts := _recipe_slot_counts()
	for tag: StringName in counts:
		var count := int(counts[tag])
		if count <= 0:
			continue
		var label := GameTerms.get_ingredient_kind_label(tag)
		# Kitchenware and Seafood read the same singular and plural.
		if count > 1 and tag != TAG_KITCHENWARE and tag != TAG_SEAFOOD:
			label += "s"
		parts.append("%d %s" % [count, label])
	return ", ".join(parts)
#endregion --- Requirements ---


#region --- Station reads for dish formulas ---
## Station cards with a kind tag, Meals and Passed Ingredients included. Used by "per Fruit on
## the station" style effects.
func _count_station_cards_by_kind(tile: Hex, kind: StringName) -> int:
	return _cards_by_kind(tile, kind, QueryScope.SAME_SEGMENT).size() + _filter_tile_cards_by_kind(_passed_in_cards(tile), kind).size()


## Flavour paid this Hour by station cards of a kind. Before they fire, their chips stand in.
## Passed Ingredients are left out: they count on this station but pay their Flavour at home.
func _station_flavour_for_kind(tile: Hex, kind: StringName, preview: bool) -> int:
	var total := 0
	for card: TileCard in _own_station_cards(tile):
		if not matches_kind_filter(card, kind):
			continue
		if card.hour_flavour_produced != 0 or not preview:
			total += card.hour_flavour_produced
			continue
		var chip: Dictionary = card.get_board_chip(_hex_for(tile, card))
		if int(chip.get("mode", BoardChipMode.HIDDEN)) == BoardChipMode.AMOUNT and card.product == Product.FLAVOUR:
			total += int(round(float(chip.get("amount", 0.0))))
	return total


## Extra triggers the Deep Fryers on this Meal's station gave this Hour. Fried Meals read it,
## which keeps them tied to Fry now that their recipes no longer name the Deep Fryer.
## Before the Deep Fryers have triggered, a preview counts what they would give.
func _deep_fryer_triggers(tile: Hex, preview: bool) -> int:
	var total := 0
	if tile == null or tile.map == null:
		return total
	for card: TileCard in _own_station_cards(tile):
		if card.id != DEEP_FRYER_ID:
			continue
		if preview and card.hour_prepared_count == 0:
			total += card.get_planned_preparations(_hex_for(tile, card))
		else:
			total += card.hour_prepared_count
	return total


## Protein is Meat, Poultry and Seafood. Used by broad effects such as French Fries. Wine stays Meat only.
func is_protein() -> bool:
	return meal_category in [MealCategory.MEAT, MealCategory.POULTRY, MealCategory.SEAFOOD]


## Meals seated on the stations either side of this one. serving_only skips Failed Meals and Meals
## idle in a locked slot, so chips and payouts agree whatever order the stations fire in.
func _neighbour_station_meals(tile: Hex, serving_only: bool = false) -> Array[MealCard]:
	var meals: Array[MealCard] = []
	if tile == null or tile.map == null:
		return meals
	var segment_index := _get_segment_index(tile)
	for side_index: int in [segment_index - 1, segment_index + 1]:
		if side_index < 0 or side_index >= _get_segment_count(tile):
			continue
		for hex: Hex in tile.map.get_hexes_in_segment(side_index):
			var meal := hex.active_tile_card as MealCard
			if meal == null:
				continue
			if serving_only and not meal.is_serving(hex):
				continue
			meals.append(meal)
	return meals


## Cards on this Meal's station, plus cards on Bars next to it whose Pairing perk shares their
## Beverages. Meals that check "a Beverage on its station" read this.
func _cards_on_beverage_stations(tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	if tile == null or tile.map == null:
		return cards
	for seg: int in StationManager.beverage_source_segments(_get_segment_index(tile)):
		for hex: Hex in tile.map.get_hexes_in_segment(seg):
			if hex.active_tile_card != null:
				cards.append(hex.active_tile_card)
	return cards


## Meals being served anywhere on the board, this one included.
func _serving_meals_on_board(tile: Hex) -> Array[MealCard]:
	var meals: Array[MealCard] = []
	for card: TileCard in _get_all_placed_tile_cards(tile, TileCardType.MEAL):
		var meal := card as MealCard
		if meal != null and meal.is_serving(_hex_for(tile, card)):
			meals.append(meal)
	return meals


func _meals_as_tile_cards(meals: Array[MealCard]) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for meal: MealCard in meals:
		cards.append(meal)
	return cards
#endregion --- Station reads for dish formulas ---
