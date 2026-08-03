extends Rune

 # +2 score for every gold you have
func _on_activate_rune(tile: Hex) -> void:
	var gold_count := GameManager.get_gold()
	var score_to_add := gold_count * score_value
	add_score(tile, score_to_add)
