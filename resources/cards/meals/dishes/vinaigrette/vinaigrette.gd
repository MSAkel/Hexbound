extends MealCard

## Needs a Vegetable and a Seasoning. +2 Mult. While it is being served, Salads on the stations
## either side of its own gain x1.5 output. Read through StationManager.output_scale_for, so a
## Salad's chip and payout both include it whichever fires first.

const SALAD_SCALE := 1.5


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount()}


func neighbour_station_output_scale_for(card: TileCard, own_tile: Hex) -> float:
	var meal := card as MealCard
	if meal == null or meal.meal_category != MealCategory.SALAD:
		return 1.0
	return SALAD_SCALE if is_serving(own_tile) else 1.0


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _neighbour_salads(hover_tile)))
	return coords


func _neighbour_salads(tile: Hex) -> Array[TileCard]:
	var salads: Array[TileCard] = []
	for meal: MealCard in _neighbour_station_meals(tile):
		if meal.meal_category == MealCategory.SALAD:
			salads.append(meal)
	return salads
