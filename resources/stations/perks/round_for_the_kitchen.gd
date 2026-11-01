extends StationPerk

## Round for the Kitchen: the first Beverage served here each Hour Garnishes one Ingredient on each
## station on either side.


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.BEVERAGE):
		return
	var state := StationManager.get_state(seg)
	if state.get("hour_round", false):
		return
	state["hour_round"] = true
	for side: int in StationManager.adjacent_segments(seg):
		for hex: Hex in StationManager.ingredient_hexes(side):
			if StationManager.garnish_from(tile, meal, hex.active_tile_card):
				break
