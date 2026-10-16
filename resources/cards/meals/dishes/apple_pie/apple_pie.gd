extends MealCard

## Needs Apple, Butter and Sugar. +5 Mult. +1 extra Gold when served with Coffee on its station.

const COFFEE_ID := "coffee"
const BONUS_GOLD := 1


func _on_activate_tile_card(tile: Hex) -> void:
	var served := is_recipe_ready(tile)
	super._on_activate_tile_card(tile)
	if served and _has_coffee(tile):
		_add_quiet_gold(tile, BONUS_GOLD)


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount()}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _coffees(hover_tile)))
	return coords


func _has_coffee(tile: Hex) -> bool:
	return not _coffees(tile).is_empty()


func _coffees(tile: Hex) -> Array[TileCard]:
	var coffees: Array[TileCard] = []
	for card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		if card.id == COFFEE_ID:
			coffees.append(card)
	return coffees
