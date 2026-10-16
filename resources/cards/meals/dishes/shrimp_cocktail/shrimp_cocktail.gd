extends MealCard

## Needs Shrimp. +2 Mult, plus +2 Mult for each Seafood on the stations either side of its own.

const MULT_PER_NEIGHBOUR_SEAFOOD := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var count := _neighbour_station_seafood(tile).size()
	return {"additive_mult": _get_production_amount() + MULT_PER_NEIGHBOUR_SEAFOOD * float(count)}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _neighbour_station_seafood(hover_tile)))
	return coords


## Seafood on the regular spots of the previous and next station.
func _neighbour_station_seafood(tile: Hex) -> Array[TileCard]:
	var seafood: Array[TileCard] = []
	if tile == null or tile.map == null:
		return seafood
	var segment_index := _get_segment_index(tile)
	for neighbour_index: int in [segment_index - 1, segment_index + 1]:
		if neighbour_index < 0 or neighbour_index >= _get_segment_count(tile):
			continue
		seafood.append_array(_filter_tile_cards_by_kind(tile.map.get_regular_tile_cards(neighbour_index), TAG_SEAFOOD))
	return seafood
