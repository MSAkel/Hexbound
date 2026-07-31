extends Rune

func _on_activate_rune(tile: Hex) -> void:
	GameManager.turn_multi += score_value
	var tile_pos := tile.map.base_layer.map_to_local(tile.coordinates)
	tile.map.create_floating_text(tile_pos, "+%d multi" % score_value, false)
