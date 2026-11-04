extends StationPerk

## Amuse-bouche: at the start of each Hour, the first Meal on the next station is Garnished.


func on_hour_started(seg: int) -> void:
	var next := StationManager.next_segment(seg)
	if next < 0:
		return
	var meals := StationManager.meal_hexes(next)
	if meals.is_empty():
		return
	meals[0].active_tile_card.add_garnish()
