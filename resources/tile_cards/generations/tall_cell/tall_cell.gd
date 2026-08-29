extends TileCard
## +10 Energy per other segment that has no Producer.

func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _get_tall_cell_amount(tile)
	if amount <= 0:
		failed_tile_card_text(tile)
		return
	add_score(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(_get_production_amount())
	return _amount_board_chip(_get_tall_cell_amount(tile))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_other_segments_matching_producer(hover_tile, false)


func _get_tall_cell_amount(tile: Hex) -> float:
	return _get_production_amount() * float(_count_other_segments_by_producer(tile, false))
