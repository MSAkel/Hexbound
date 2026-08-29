extends TileCard
## +24 Energy if this is the last Producer in the segment, otherwise +8.

const LAST_PRODUCER_AMOUNT := 24
const OTHER_PRODUCER_AMOUNT := 8


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_last_surge_amount(tile))


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(LAST_PRODUCER_AMOUNT)
	return _amount_board_chip(_get_last_surge_amount(tile))


func _get_last_surge_amount(tile: Hex) -> int:
	if _is_last_producer_in_segment(tile):
		return LAST_PRODUCER_AMOUNT
	return OTHER_PRODUCER_AMOUNT
