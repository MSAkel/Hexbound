extends MealCard

## Needs Chicken, a Seasoning and a Deep Fryer. +60 Flavour. Doubled while a Side is being served
## on a station either side of its own. Several Sides still double it only once.

const SIDE_SCALE := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var flavour := _get_production_amount()
	if not _serving_neighbour_sides(tile).is_empty():
		flavour *= SIDE_SCALE
	return {"flavour": int(round(flavour))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meals_as_tile_cards(_serving_neighbour_sides(hover_tile))))
	return coords


func _serving_neighbour_sides(tile: Hex) -> Array[MealCard]:
	var sides: Array[MealCard] = []
	for meal: MealCard in _neighbour_station_meals(tile, true):
		if meal.meal_category == MealCategory.SIDE:
			sides.append(meal)
	return sides
