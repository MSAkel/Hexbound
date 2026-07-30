extends Rune

func _on_activate_rune(tile: Hex) -> void:
	# Basic runes generate influence when triggered at end of turn
	GameManager.influence_progress += 20
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, "+20 Influence", false)
