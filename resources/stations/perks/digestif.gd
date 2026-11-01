extends StationPerk

## Digestif: after a Dessert is served on an adjacent station, the next Beverage here is Garnished.


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if not meal_seg in StationManager.adjacent_segments(seg):
		return
	if not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.DESSERT):
		return
	for hex: Hex in StationManager.meal_hexes(seg):
		var drink := hex.active_tile_card as MealCard
		if StationManager.meal_counts_as(drink, hex, MealCard.MealCategory.BEVERAGE):
			if StationManager.garnish_from(tile, meal, drink):
				return
