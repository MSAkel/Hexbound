extends Rune

func _on_activate_rune(tile: Hex) -> void:
	# Basic runes generate score when triggered at end of turn
	GameManager.turn_score += score_value
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, "+%d score" % score_value, false)
