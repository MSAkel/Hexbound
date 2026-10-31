extends MealCard

## Needs Avocado, Chili and a Kitchenware. +2 Mult, plus +2 Mult for each Meal being served on the
## stations either side of its own.

const MULT_PER_NEIGHBOUR_MEAL := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_NEIGHBOUR_MEAL * float(_neighbour_station_meals(tile, true).size())}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meals_as_tile_cards(_neighbour_station_meals(hover_tile, true))))
	return coords
