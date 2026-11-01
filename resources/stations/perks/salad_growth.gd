extends StationPerk

## Cold level 3 A: Vegetables here gain flat_flavour for every Salad served on any station, for the
## rest of the run. The count lives in the station state, so it resets if the station loses its type.


func flat_flavour_on_station(seg: int, _tile: Hex, card: TileCard) -> int:
	if not matches(card):
		return 0
	return flat_flavour * int(StationManager.get_state(seg).get("salads", 0))


func on_meal_served(seg: int, _meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.SALAD):
		var state := StationManager.get_state(seg)
		state["salads"] = int(state.get("salads", 0)) + 1
