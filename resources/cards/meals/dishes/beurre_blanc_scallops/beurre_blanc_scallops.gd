extends MealCard

## Needs Scallop, Butter and a Fruit. x2 Mult, or x2.5 Mult while a Sauce & Dip Meal is being
## served on the station above or below its own.

const BASE_XMULT := 2.0
const SAUCE_XMULT := 2.5


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"multiplicative_mult": SAUCE_XMULT if not _serving_neighbour_sauces(tile).is_empty() else BASE_XMULT}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meals_as_tile_cards(_serving_neighbour_sauces(hover_tile))))
	return coords


func _serving_neighbour_sauces(tile: Hex) -> Array[MealCard]:
	var sauces: Array[MealCard] = []
	for meal: MealCard in _neighbour_station_meals(tile, true):
		if meal.meal_category == MealCategory.SAUCE:
			sauces.append(meal)
	return sauces
