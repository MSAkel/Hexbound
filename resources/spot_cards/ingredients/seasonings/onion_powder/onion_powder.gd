extends TileCard
## +2 Mult per other course that contains a Ingredient.

func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _get_wide_ratio_amount(tile)
	if amount <= 0.0:
		failed_tile_card_text(tile)
		return
	add_additive_mult(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip_float(_get_production_amount())
	return _amount_board_chip_float(_get_wide_ratio_amount(tile))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_other_segments_matching_producer(hover_tile, true)


func _count_other_segments_with_producer(tile: Hex) -> int:
	return _count_other_segments_by_producer(tile, true)


func _get_wide_ratio_amount(tile: Hex) -> float:
	# Each other Producer segment adds base_production_amount Mult (2).
	return _get_production_amount() * float(_count_other_segments_with_producer(tile))
