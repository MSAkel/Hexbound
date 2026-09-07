extends TileCard

## +2 Mult per current turn.
func _on_activate_tile_card(tile: Hex) -> void:
	# Use turn number (counts up), not remaining turns (counts down).
	_pay_effect_amount(tile)


func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount() * float(GameManager.get_turn_number())
