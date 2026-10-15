extends MealCard

## Needs Lobster and Butter. +60 Flavour. Doubled when every Seafood on its station is Garnished.

const GARNISHED_SCALE := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var flavour := _get_production_amount()
	if _all_seafood_garnished(tile):
		flavour *= GARNISHED_SCALE
	return {"flavour": int(round(flavour))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_station_seafood_coords(hover_tile))
	return coords


func _station_seafood_coords(tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(tile, _filter_tile_cards_by_kind(_station_cards(tile), TAG_SEAFOOD))


func _all_seafood_garnished(tile: Hex) -> bool:
	var seafood := _filter_tile_cards_by_kind(_station_cards(tile), TAG_SEAFOOD)
	if seafood.is_empty():
		return false
	return seafood.all(func(card: TileCard) -> bool: return card.is_garnished)
