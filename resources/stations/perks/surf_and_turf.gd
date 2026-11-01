extends StationPerk

## Surf & Turf: Seafood meals here gain output_scale while a Meat meal is being served on a Grilling
## Station.
const GRILL_TYPE_ID := "grilling_station"


func output_scale_on_station(_seg: int, tile: Hex, card: TileCard) -> float:
	var meal := card as MealCard
	if meal == null or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.SEAFOOD):
		return 1.0
	for grill: int in StationManager.segments_of_type(GRILL_TYPE_ID):
		for hex: Hex in StationManager.meal_hexes(grill):
			var other := hex.active_tile_card as MealCard
			if other.is_serving(hex) and StationManager.meal_counts_as(other, hex, MealCard.MealCategory.MEAT):
				return output_scale
	return 1.0
