extends StationPerk

## Mother Sauce: the first Sauce & Dip meal served here each Hour Garnishes one Meal on each station
## on either side.


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.SAUCE):
		return
	var state := StationManager.get_state(seg)
	if state.get("hour_mother_sauce", false):
		return
	state["hour_mother_sauce"] = true
	for side: int in StationManager.adjacent_segments(seg):
		for hex: Hex in StationManager.meal_hexes(side):
			if StationManager.sauce_garnish(tile, meal, hex, hex.active_tile_card):
				break
