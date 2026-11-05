extends MealCard

## Needs Cheese, a Seasoning and a Kitchenware. +3 Mult, plus +2 Mult for each Side being served on
## the stations either side of its own.

const MULT_PER_SIDE := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_SIDE * float(_serving_neighbour_sides(tile).size())}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meals_as_tile_cards(_serving_neighbour_sides(hover_tile))))
	return coords


func _serving_neighbour_sides(tile: Hex) -> Array[MealCard]:
	var sides: Array[MealCard] = []
	for meal: MealCard in _neighbour_station_meals(tile, true):
		# Fish & Chips (Fry Station) can make a Seafood meal count as a Side.
		if StationManager.meal_counts_as(meal, _hex_for(tile, meal), MealCategory.SIDE):
			sides.append(meal)
	return sides
