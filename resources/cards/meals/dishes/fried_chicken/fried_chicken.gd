extends MealCard

## Needs Chicken and a Seasoning. +60 Flavour, plus +20 Flavour for each extra trigger a Deep Fryer
## on its station gives this Hour. Doubled while a Side is being served on a station either side of
## its own. Several Sides still double it only once.

const SIDE_SCALE := 2.0
const FLAVOUR_PER_FRY := 20.0


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var flavour := _get_production_amount() + FLAVOUR_PER_FRY * float(_deep_fryer_triggers(tile, preview))
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
		# Fish & Chips (Fry Station) can make a Seafood meal count as a Side.
		if StationManager.meal_counts_as(meal, _hex_for(tile, meal), MealCategory.SIDE):
			sides.append(meal)
	return sides
