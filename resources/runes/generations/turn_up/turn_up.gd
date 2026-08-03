extends Rune

# Gains Mult equal to the current turn x 4
func _on_activate_rune(tile: Hex) -> void:
	add_multiplier(tile, score_value * GameManager.current_turn)
