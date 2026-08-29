extends TileCard
## +3 Energy per empty tile in this segment, capped at 30.

const ENERGY_PER_EMPTY := 3
const ENERGY_CAP := 30


func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _get_open_circuit_amount(tile)
	if amount <= 0:
		failed_tile_card_text(tile)
		return
	add_score(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(ENERGY_PER_EMPTY)
	return _amount_board_chip(_get_open_circuit_amount(tile))


func _get_open_circuit_amount(tile: Hex) -> int:
	var empty := tile.map.get_empty_tile_count_in_segment(_get_segment_index(tile))
	return mini(ENERGY_CAP, ENERGY_PER_EMPTY * empty)
