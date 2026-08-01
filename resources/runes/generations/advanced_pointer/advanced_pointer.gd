extends Rune

# +15 score for every adjacent score rune. +50 score if all adjacent tiles are score runes
func _on_activate_rune(_tile: Hex) -> void:
	var adjacent_generators_count = get_occupied_adjacent_count(_tile, Rune.RuneType.GENERATION)
	if adjacent_generators_count > 0:
		var score_to_add = 15 * adjacent_generators_count
		if adjacent_generators_count == 5:
			score_to_add += 50
		add_score(_tile, score_to_add)
