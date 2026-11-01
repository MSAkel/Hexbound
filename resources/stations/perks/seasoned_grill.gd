extends StationPerk

## Seasoned Grill: at the end of each Day, Seafood meals served (not Failed) on this station that Day
## gain growth_per_day output for good. The growth is stored on the Meal and works on this station.
const GROWTH_KEY := "seasoned_grill"
@export var growth_per_day: float = 0.1


func output_scale_on_station(_seg: int, _tile: Hex, card: TileCard) -> float:
	if not card is MealCard:
		return 1.0
	return 1.0 + float(card.perk_growth.get(GROWTH_KEY, 0.0))


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.SEAFOOD):
		return
	var served: Array = StationManager.get_state(seg).get_or_add("day_served", [])
	var key := "%d,%d" % [tile.coordinates.x, tile.coordinates.y]
	if not key in served:
		served.append(key)


func on_day_ended(seg: int) -> void:
	var served: Array = StationManager.get_state(seg).get("day_served", [])
	for hex: Hex in StationManager.meal_hexes(seg):
		var key := "%d,%d" % [hex.coordinates.x, hex.coordinates.y]
		if key in served:
			var meal := hex.active_tile_card
			meal.perk_growth[GROWTH_KEY] = float(meal.perk_growth.get(GROWTH_KEY, 0.0)) + growth_per_day
