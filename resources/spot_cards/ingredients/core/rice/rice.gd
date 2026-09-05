extends TileCard

## +8 Flavour per adjacent Seasoning.
func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _get_adjacent_seasoning_amount(tile)
	if amount <= 0.0:
		return
	add_score(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(base_production_amount)
	return _amount_board_chip(_get_adjacent_seasoning_amount(tile))


func _get_adjacent_seasoning_amount(tile: Hex) -> float:
	var seasonings := _get_adjacent_tile_cards_by_product(tile, Product.MULTIPLIER)
	return _get_production_amount() * seasonings.size()


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_tile_cards_by_product(hover_tile, Product.MULTIPLIER)