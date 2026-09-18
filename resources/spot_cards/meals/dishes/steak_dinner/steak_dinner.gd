extends MealCard

## +60 Flavour when the prefix is Protein plus Kitchenware.
## Doubled when the Following neighbour is a Beverage.


func _plated_flavour_from_recipe(_recipe: Array[TileCard]) -> int:
	return int(round(_get_production_amount()))


func _on_activate_tile_card(tile: Hex) -> void:
	if _is_beverage_card(_get_following_neighbouring_card(tile)):
		_empower()
	super._on_activate_tile_card(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	var neighbour := _get_following_neighbouring_card(hover_tile)
	if neighbour != null:
		coords.append_array(_coords_for_placed_tile_cards(hover_tile, [neighbour]))
	return coords


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	var gold := super.get_trigger_preview_gold_coords(hover_tile)
	var neighbour := _get_following_neighbouring_card(hover_tile)
	if not _is_beverage_card(neighbour):
		return gold
	gold.append_array(_coords_for_placed_tile_cards(hover_tile, [neighbour]))
	return gold


## First occupied adjacent spot that fires after this dish.
func _get_following_neighbouring_card(tile: Hex) -> TileCard:
	var following := _get_following_adjacent_tile_cards(tile)
	if following.is_empty():
		return null
	return following[0]


func _is_beverage_card(card: TileCard) -> bool:
	return card != null and card.has_ingredient_tag(TAG_BEVERAGE)
