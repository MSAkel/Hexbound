extends TileCard


# Gain 2 gold
func _on_activate_tile_card(tile: Hex) -> void:
	add_gold(tile, 2)
