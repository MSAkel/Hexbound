extends MealCard

## Needs Salmon, Honey and a Kitchenware. +60 Flavour, plus +20 Flavour for each Sweet on its station.

const FLAVOUR_PER_SWEET := 20.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var sweets := _filter_tile_cards_by_kind(_station_cards(tile), TAG_SWEET).size()
	return {"flavour": int(round(_get_production_amount() + FLAVOUR_PER_SWEET * float(sweets)))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_cards_by_kind(hover_tile, TAG_SWEET, QueryScope.SAME_SEGMENT))
	return coords
