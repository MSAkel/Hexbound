extends Rune

# Gains Mult equal to the current turn x 3
func _on_activate_rune(tile: Hex) -> void:
	add_multiplier(tile, _get_production_amount() * GameManager.current_turn)
