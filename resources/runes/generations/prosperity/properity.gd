extends Rune

# +5 score for every 1 gold earned this turn
func _on_activate_rune(tile: Hex) -> void:
	var gold_earned := GoldManager.earned_this_turn
	var score_to_add := gold_earned * base_production_amount
	add_score(tile, score_to_add)
