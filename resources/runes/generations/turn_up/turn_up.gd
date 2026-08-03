extends Rune

# Gains Mult equal to the current turn x 4
func _on_activate_rune(tile: Hex) -> void:
	GameManager.turn_multi += score_value * GameManager.current_turn
	create_floating_text(tile, "+%d multiplier" % (score_value * GameManager.current_turn))
