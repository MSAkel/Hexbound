extends MealCard

## Needs Chocolate. Starts at x1 Mult and gains x0.5 for each different Sweet on its station.

const XMULT_PER_SWEET := 0.5


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var sweet_count := 1 if tile == null else _different_sweet_count(tile)
	return {"multiplicative_mult": 1.0 + XMULT_PER_SWEET * float(sweet_count)}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_cards_by_kind(hover_tile, TAG_SWEET, QueryScope.SAME_SEGMENT))
	return coords


func _different_sweet_count(tile: Hex) -> int:
	var ids := {}
	for card: TileCard in _filter_tile_cards_by_kind(_station_cards(tile), TAG_SWEET):
		ids[card.id] = true
	return ids.size()
