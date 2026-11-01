extends StationPerk

## Roast Dinner: while a Meat meal is being served on this station, Side meals on the next station
## gain output_scale.


func output_scale_elsewhere(seg: int, card_seg: int, tile: Hex, card: TileCard) -> float:
	var meal := card as MealCard
	if meal == null or card_seg != StationManager.next_segment(seg):
		return 1.0
	if not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.SIDE):
		return 1.0
	for hex: Hex in StationManager.meal_hexes(seg):
		var roast := hex.active_tile_card as MealCard
		if roast.is_serving(hex) and StationManager.meal_counts_as(roast, hex, MealCard.MealCategory.MEAT):
			return output_scale
	return 1.0
