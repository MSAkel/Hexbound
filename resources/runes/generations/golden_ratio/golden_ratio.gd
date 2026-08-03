extends Rune

# +1 multiplier for every 1 gold earned this turn
func _on_activate_rune(tile: Hex) -> void:
	var multiplier_to_add := GameManager.gold_earned_this_turn
	GameManager.turn_multi += multiplier_to_add
	create_floating_text(tile, "+%d multiplier" % multiplier_to_add)
