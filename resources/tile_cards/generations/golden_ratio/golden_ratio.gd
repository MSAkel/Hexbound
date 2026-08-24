extends TileCard

## +3 Mult. Gain +1 Mult for each Gold spent this round.
func _on_activate_tile_card(tile: Hex) -> void:
	add_multiplier(tile, _get_production_amount() + GoldManager.spent_this_round)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _amount_board_chip(_get_production_amount() + GoldManager.spent_this_round)
