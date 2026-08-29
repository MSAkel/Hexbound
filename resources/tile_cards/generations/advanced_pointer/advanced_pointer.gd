extends TileCard

## +14 Energy per adjacent Downstream Energy card. +20 extra if 2 or more.
func _on_activate_tile_card(_tile: Hex) -> void:
	var amount := _get_pointer_amount(_tile)
	if amount <= 0.0:
		return
	add_score(_tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(base_production_amount)
	return _amount_board_chip(_get_pointer_amount(tile))


func _get_pointer_amount(tile: Hex) -> float:
	var neighboring_energy := _get_downstream_adjacent_tile_cards_by_product(tile, Product.SCORE)
	var score_to_add := _get_production_amount() * neighboring_energy.size()
	if neighboring_energy.size() >= 2:
		score_to_add += 20
	return score_to_add


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_downstream_adjacent_tile_cards_by_product(hover_tile, Product.SCORE)
