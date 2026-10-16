extends MealCard

## +80 Flavour. Doubled when a Beverage is served on the same station.

const BEVERAGE_SCALE := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var flavour := _get_production_amount()
	if _count_station_cards_by_kind(tile, TAG_BEVERAGE) > 0:
		flavour *= BEVERAGE_SCALE
	return {"flavour": int(round(flavour))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_cards_by_kind(hover_tile, TAG_BEVERAGE, QueryScope.SAME_SEGMENT))
	return coords
