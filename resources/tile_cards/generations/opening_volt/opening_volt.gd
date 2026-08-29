extends TileCard
## +24 Energy if this is the first Producer in the segment, otherwise +8.

const FIRST_PRODUCER_AMOUNT := 24
const OTHER_PRODUCER_AMOUNT := 8


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_opening_volt_amount(tile))


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(FIRST_PRODUCER_AMOUNT)
	return _amount_board_chip(_get_opening_volt_amount(tile))


func _get_opening_volt_amount(tile: Hex) -> int:
	if _is_first_producer_in_segment(tile):
		return FIRST_PRODUCER_AMOUNT
	return OTHER_PRODUCER_AMOUNT
