extends MealCard

## Needs 2 Meats and a Seasoning. +2 Mult, plus +1 Mult for each Meat on its station.

const MULT_PER_MEAT := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_MEAT * float(_station_meats(tile).size())}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _station_meats(hover_tile)))
	return coords


func _station_meats(tile: Hex) -> Array[TileCard]:
	return _filter_tile_cards_by_kind(_station_cards(tile), TAG_MEAT)
