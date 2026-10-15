extends MealCard

## Starts at x1 Mult and gains x0.5 for every Fruit on its station.

const XMULT_PER_FRUIT := 0.5


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var fruit_count := _count_station_cards_by_kind(tile, TAG_FRUIT)
	if tile == null:
		fruit_count = 1
	return {"multiplicative_mult": 1.0 + XMULT_PER_FRUIT * float(fruit_count)}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_cards_by_kind(hover_tile, TAG_FRUIT, QueryScope.SAME_SEGMENT)
