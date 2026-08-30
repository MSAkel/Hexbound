extends TileCard
## +6 Mult if this segment has 7 tiles or fewer.

const MAX_SEGMENT_SIZE := 7


func _on_activate_tile_card(tile: Hex) -> void:
	# Compact Power is an Uncommon short-line spike. Longer rings get nothing.
	if _get_segment_size(tile) <= MAX_SEGMENT_SIZE:
		add_multiplier(tile, _get_production_amount())
	else:
		failed_tile_card_text(tile)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile != null and _get_segment_size(tile) > MAX_SEGMENT_SIZE:
		return _amount_board_chip(0, ICON_MULT)
	return _amount_board_chip(_get_production_amount(), ICON_MULT)
