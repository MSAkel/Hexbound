extends MealCard

## Needs Corn and a Seasoning. +40 Flavour, plus +10 Flavour for each Kitchenware on its station.

const FLAVOUR_PER_KITCHENWARE := 10.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var kitchenware := _filter_tile_cards_by_kind(_station_cards(tile), TAG_KITCHENWARE).size()
	return {"flavour": int(round(_get_production_amount() + FLAVOUR_PER_KITCHENWARE * float(kitchenware)))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_cards_by_kind(hover_tile, TAG_KITCHENWARE, QueryScope.SAME_SEGMENT))
	return coords
