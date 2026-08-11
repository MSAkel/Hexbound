extends Rune

# +15 score for every adjacent score rune. +50 score if all adjacent tiles are score runes
func _on_activate_rune(_tile: Hex) -> void:
	var adjacent_generators_count = _count_all_occupied_adjacent_runes(_tile, Rune.RuneType.PRODUCER)
	if adjacent_generators_count > 0:
		var score_to_add = 15 * adjacent_generators_count
		if adjacent_generators_count == 5:
			score_to_add += 50
		add_score(_tile, score_to_add)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_runes_by_product(hover_tile, Product.SCORE)
