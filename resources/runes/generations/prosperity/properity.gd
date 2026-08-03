extends Rune

# +5 score for every 1 gold earned this turn
func _on_activate_rune(tile: Hex) -> void:
	var gold_earned := GameManager.gold_earned_this_turn
	var score_to_add := gold_earned * score_value
	add_score(tile, score_to_add)
