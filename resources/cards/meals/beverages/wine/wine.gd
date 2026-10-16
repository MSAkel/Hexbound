extends MealCard

## Needs Grape on its station. +10 Mult, then x1 Mult that gains x0.5 for each station
## serving a Meat dish.

const XMULT_PER_MEAT_STATION := 0.5


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {
		"additive_mult": _get_production_amount(),
		"multiplicative_mult": 1.0 + XMULT_PER_MEAT_STATION * float(_meat_dish_station_count(tile)),
	}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meat_dishes(hover_tile)))
	return coords


func _meat_dish_station_count(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return 0
	var stations := {}
	for dish: TileCard in _meat_dishes(tile):
		stations[tile.map.get_segment_index(_hex_for(tile, dish).coordinates)] = true
	return stations.size()


func _meat_dishes(tile: Hex) -> Array[TileCard]:
	var dishes: Array[TileCard] = []
	for card: TileCard in _get_all_placed_tile_cards(tile, TileCardType.MEAL):
		var meal := card as MealCard
		if meal != null and meal.recipe_protein_count > 0:
			dishes.append(card)
	return dishes
