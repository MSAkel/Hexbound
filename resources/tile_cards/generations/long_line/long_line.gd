extends TileCard
## +3 Energy per tile in this segment, capped at 30.

const ENERGY_PER_TILE := 3
const ENERGY_CAP := 30


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_long_line_amount(tile))


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(ENERGY_PER_TILE)
	return _amount_board_chip(_get_long_line_amount(tile))


func _get_long_line_amount(tile: Hex) -> int:
	return mini(ENERGY_CAP, ENERGY_PER_TILE * _get_segment_size(tile))
