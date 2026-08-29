extends TileCard
## +6 Mult if segment size is less than 6

func _on_activate_tile_card(tile: Hex) -> void:
	# Compact Power is an Uncommon small-segment spike. Large lines get nothing.
	var segment_size := _get_segment_size(tile)
	if segment_size < 6:
		add_multiplier(tile, _get_production_amount())
	else:
		failed_tile_card_text(tile)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile != null and _get_segment_size(tile) >= 6:
		return _amount_board_chip(0, ICON_MULT)
	return _amount_board_chip(_get_production_amount(), ICON_MULT)
