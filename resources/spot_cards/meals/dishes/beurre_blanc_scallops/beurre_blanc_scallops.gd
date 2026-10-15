extends MealCard

## Needs Scallop, Butter and Lemon. +70 Flavour. Doubled when Wine is served on its station.

const WINE_ID := "wine"
const WINE_SCALE := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var flavour := _get_production_amount()
	if not _wines(tile).is_empty():
		flavour *= WINE_SCALE
	return {"flavour": int(round(flavour))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _wines(hover_tile)))
	return coords


func _wines(tile: Hex) -> Array[TileCard]:
	var wines: Array[TileCard] = []
	for card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		if card.id == WINE_ID:
			wines.append(card)
	return wines
