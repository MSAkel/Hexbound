extends Rune

# Converts all gold generated so far this turn into Mult
func _on_activate_rune(tile: Hex) -> void:
	var gold_earned_so_far := GoldManager.earned_this_turn
	if gold_earned_so_far > 0:
		GoldManager.remove(gold_earned_so_far)
		GoldManager.earned_this_turn = 0
		
	add_multiplier(tile, gold_earned_so_far)
