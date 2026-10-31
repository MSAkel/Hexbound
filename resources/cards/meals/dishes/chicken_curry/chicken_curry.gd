extends MealCard

## Needs Chicken and Turmeric. +4 Mult, plus +2 Mult for each different Seasoning on its station.

const MULT_PER_SEASONING := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_SEASONING * float(_different_seasoning_count(tile))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_cards_by_kind(hover_tile, TAG_SEASONING, QueryScope.SAME_SEGMENT))
	return coords


func _different_seasoning_count(tile: Hex) -> int:
	var ids := {}
	for card: TileCard in _filter_tile_cards_by_kind(_station_cards(tile), TAG_SEASONING):
		ids[card.id] = true
	return ids.size()
