extends MealCard

## Needs Milk and a Sweet. +2 Mult, plus +1 Mult for each Sweet or Dairy on its station.

const MULT_PER_CARD := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_CARD * float(_sweets_and_dairy(tile).size())}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _sweets_and_dairy(hover_tile)))
	return coords


## A card that is both Sweet and Dairy counts once.
func _sweets_and_dairy(tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for card: TileCard in _station_cards(tile):
		if card.has_ingredient_tag(TAG_SWEET) or card.has_ingredient_tag(TAG_DAIRY):
			cards.append(card)
	return cards
