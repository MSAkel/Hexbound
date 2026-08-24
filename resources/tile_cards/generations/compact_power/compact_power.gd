extends TileCard
##  +15 Mult if segment size is less than 6

func _on_activate_tile_card(tile: Hex) -> void:
	var segment_size := _get_segment_size(tile)
	if segment_size < 6:
		add_multiplier(tile, 15)
	else:
		_create_floating_text(tile, "Failed", Color.RED)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile != null and _get_segment_size(tile) >= 6:
		return _hidden_board_chip()
	return _amount_board_chip(15, ICON_MULT)
