extends MealCard

## Needs Olive and a Seasoning. +2 Mult, plus +1 Mult for each time an Olive on its station has
## fired this Hour.

const OLIVE_ID := "olive"
const MULT_PER_OLIVE_FIRE := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_OLIVE_FIRE * float(_olive_fires(tile))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _olives(hover_tile)))
	return coords


func _olive_fires(tile: Hex) -> int:
	var fires := 0
	for olive: TileCard in _olives(tile):
		fires += GameManager.get_tile_card_activation_count_this_turn(olive)
	return fires


func _olives(tile: Hex) -> Array[TileCard]:
	var olives: Array[TileCard] = []
	for card: TileCard in _station_cards(tile):
		if card.id == OLIVE_ID:
			olives.append(card)
	return olives
