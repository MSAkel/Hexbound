extends MealCard

## Combo meal. +40 Flavour and +4 Mult, +2 Mult if French Fries is served on any station, +25 Flavour
## if a Beverage is served on any station. A Meal counts when it would be served right now (its
## recipe is on its station and it is not idle in a locked Meal slot); it does not need to have
## fired yet. No xMult (Meals no longer give it). Untuned.

const BASE_FLAVOUR := 40
const FRIES_ID := "french_fries"
const FRIES_MULT := 2.0
const BEVERAGE_FLAVOUR := 25


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var flavour := BASE_FLAVOUR
	var mult := _get_production_amount()
	if not _serving_fries(tile).is_empty():
		mult += FRIES_MULT
	if not _serving_beverages(tile).is_empty():
		flavour += BEVERAGE_FLAVOUR
	return {
		"flavour": flavour,
		"additive_mult": mult,
	}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _serving_fries(hover_tile)))
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _serving_beverages(hover_tile)))
	return coords


func _serving_fries(tile: Hex) -> Array[TileCard]:
	return _serving_meals(tile, func(meal: MealCard) -> bool: return meal.id == FRIES_ID)


func _serving_beverages(tile: Hex) -> Array[TileCard]:
	return _serving_meals(tile, func(meal: MealCard) -> bool:
		return meal.meal_category == MealCategory.BEVERAGE)


## Every placed Meal matching the filter that would be served right now, on any station.
func _serving_meals(tile: Hex, matches: Callable) -> Array[TileCard]:
	var found: Array[TileCard] = []
	if tile == null or tile.map == null:
		return found
	for card: TileCard in _get_all_placed_tile_cards(tile, TileCardType.MEAL):
		var meal := card as MealCard
		if meal == null or meal == self or not bool(matches.call(meal)):
			continue
		if meal.is_serving(_hex_for(tile, card)):
			found.append(card)
	return found
