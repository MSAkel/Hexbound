extends TileCard

func _on_activate_tile_card(tile: Hex) -> void:
	if tile.map.is_edge_tile(tile.coordinates):
		add_flavour(tile, _get_production_amount())
