extends Rune

# +1 multiplier for every 1 gold earned this turn
func _on_activate_rune(tile: Hex) -> void:
	add_multiplier(tile, GoldManager.earned_this_turn)
