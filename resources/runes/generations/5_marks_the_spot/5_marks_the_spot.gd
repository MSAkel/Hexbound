extends Rune

# +5 gold if exactly 5 runes were activated so far this round
func _on_activate_rune(_tile: Hex) -> void:
	# 6 because the current rune is also counted
	if get_activations_this_turn() == 6:
		GameManager.add_gold(5)
