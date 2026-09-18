extends TileCard

## +2 Mult per current turn. Uses turn number, which counts up, not remaining turns.
func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount() * float(GameManager.get_turn_number())
