extends MealCard

## Needs Chili Pepper, a Vegetable and a Fruit. +3 Mult, plus +1 Mult for each different Vegetable
## or Fruit on its station. Copies of the same card count once.

const MULT_PER_PRODUCE := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_PRODUCE * float(_different_produce_ids(tile).size())}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _produce(hover_tile)))
	return coords


func _produce(tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for card: TileCard in _station_cards(tile):
		if card.has_ingredient_tag(TAG_VEGETABLE) or card.has_ingredient_tag(TAG_FRUIT):
			cards.append(card)
	return cards


func _different_produce_ids(tile: Hex) -> Dictionary:
	var ids := {}
	for card: TileCard in _produce(tile):
		ids[card.id] = true
	return ids
