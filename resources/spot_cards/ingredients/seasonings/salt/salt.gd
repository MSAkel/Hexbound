extends TileCard

func _on_activate_tile_card(tile: Hex) -> void:
	add_additive_mult(tile, _get_production_amount())
