extends MealCard

## Needs Onion. +50 Flavour, plus +15 Flavour for each extra trigger a Deep Fryer on its station
## gives this Hour. Doubled while another Side is being served in the other Meal slot of its own
## station. Failed Meals and Meals idle in a locked slot do not count.

const SIDE_SCALE := 2.0
const FLAVOUR_PER_FRY := 15.0


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var flavour := _get_production_amount() + FLAVOUR_PER_FRY * float(_deep_fryer_triggers(tile, preview))
	if not _other_serving_sides(tile).is_empty():
		flavour *= SIDE_SCALE
	return {"flavour": int(round(flavour))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meals_as_tile_cards(_other_serving_sides(hover_tile))))
	return coords


func _other_serving_sides(tile: Hex) -> Array[MealCard]:
	var sides: Array[MealCard] = []
	if tile == null or tile.map == null:
		return sides
	for hex: Hex in tile.map.get_hexes_in_segment(_get_segment_index(tile)):
		var meal := hex.active_tile_card as MealCard
		if meal == null or meal == self or not meal.is_serving(hex):
			continue
		# Fish & Chips (Fry Station) can make a Seafood meal count as a Side.
		if StationManager.meal_counts_as(meal, hex, MealCategory.SIDE):
			sides.append(meal)
	return sides
