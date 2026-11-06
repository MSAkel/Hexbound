extends MealCard

## Needs Lobster and Butter. +40 Flavour, plus +25 Flavour for each Garnished Ingredient on its
## station. A Garnish lasts the rest of the Hour once its card triggers, so an Ingredient that
## triggered Garnished this Hour still counts. Stacks don't count twice.

const FLAVOUR_PER_GARNISHED := 25.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"flavour": int(round(_get_production_amount() + FLAVOUR_PER_GARNISHED * float(_garnished_ingredients(tile).size())))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _garnished_ingredients(hover_tile)))
	return coords


func _garnished_ingredients(tile: Hex) -> Array[TileCard]:
	var garnished: Array[TileCard] = []
	if tile == null:
		return garnished
	for card: TileCard in _station_cards(tile):
		if card.type == TileCardType.INGREDIENT and (card.is_garnished or card.hour_was_garnished):
			garnished.append(card)
	return garnished
