extends TileCard
## +1 Mult per other segment that contains a Producer.

func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _count_other_segments_with_producer(tile)
	if amount <= 0:
		failed_tile_card_text(tile)
		return
	add_multiplier(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip_float(_get_production_amount())
	return _amount_board_chip_float(float(_count_other_segments_with_producer(tile)))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_other_segments_matching_producer(hover_tile, true)


func _count_other_segments_with_producer(tile: Hex) -> int:
	return _count_other_segments_by_producer(tile, true)
