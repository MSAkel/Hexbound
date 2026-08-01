extends Rune

func _on_activate_rune(tile: Hex) -> void:
	if is_on_map_edge(tile):
		add_score(tile, score_value)