extends MealCard

## Needs Sausage and a Vegetable. +3 Mult. +1 extra Gold when served with a Beverage on its station.

const BONUS_GOLD := 1


func _on_activate_tile_card(tile: Hex) -> void:
	var served := is_recipe_ready(tile)
	super._on_activate_tile_card(tile)
	if served and not _beverages(tile).is_empty():
		_add_quiet_gold(tile, BONUS_GOLD)


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount()}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _beverages(hover_tile)))
	return coords


func _beverages(tile: Hex) -> Array[TileCard]:
	var beverages: Array[TileCard] = []
	for card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		if card != self and card.has_ingredient_tag(TAG_BEVERAGE):
			beverages.append(card)
	return beverages
