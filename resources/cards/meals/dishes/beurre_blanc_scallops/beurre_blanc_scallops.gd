extends MealCard

## Needs Scallop, Butter and a Fruit. +60 Flavour and +3 Mult, and +60 Flavour more while a
## Sauce & Dip Meal is being served on the station above or below its own. No xMult (Meals no
## longer give it). Untuned.

const BASE_FLAVOUR := 60
const SAUCE_FLAVOUR := 60


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var sauce := SAUCE_FLAVOUR if not _serving_neighbour_sauces(tile).is_empty() else 0
	return {
		"additive_mult": _get_production_amount(),
		"flavour": BASE_FLAVOUR + sauce,
	}


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
