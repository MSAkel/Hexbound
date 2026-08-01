extends Rune

# +5 points increasing by 5 every 2 turns up to a maximum of 70
func _on_activate_rune(tile: Hex) -> void:
	var points_to_add := score_value
	add_score(tile, points_to_add)
	score_value += 5
	if score_value > 70:
		score_value = 70