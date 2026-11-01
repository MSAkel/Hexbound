extends StationPerk

## Pan Drippings: each Meat meal served here Garnishes a Sauce & Dip meal on an adjacent Sauce Station.
const SAUCE_TYPE_ID := "sauce_station"


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.MEAT):
		return
	for side: int in StationManager.adjacent_segments(seg):
		if StationManager.get_station_type_id(side) != SAUCE_TYPE_ID:
			continue
		for hex: Hex in StationManager.meal_hexes(side):
			var target := hex.active_tile_card as MealCard
			if StationManager.meal_counts_as(target, hex, MealCard.MealCategory.SAUCE):
				if StationManager.garnish_from(tile, meal, target):
					return
