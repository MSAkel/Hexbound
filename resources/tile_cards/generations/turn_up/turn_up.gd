extends TileCard

## +3 Mult per current turn.
func _on_activate_tile_card(tile: Hex) -> void:
	# Use turn number (counts up), not remaining turns (counts down).
	add_multiplier(tile, _get_production_amount() * GameManager.get_turn_number())


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _amount_board_chip_float(_get_production_amount() * float(GameManager.get_turn_number()))
