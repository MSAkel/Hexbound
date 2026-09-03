extends TileCard
## +12 Flavour per course that has already received a pass this hour.

func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _get_relay_sink_amount(tile)
	if amount <= 0:
		failed_tile_card_text(tile)
		return
	add_score(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(_get_production_amount())
	return _amount_board_chip(_get_relay_sink_amount(tile))


func _get_relay_sink_amount(tile: Hex) -> float:
	return _get_production_amount() * float(tile.map.count_segments_that_received_relay())
