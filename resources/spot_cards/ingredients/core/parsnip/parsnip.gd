extends TileCard

func _on_activate_tile_card(tile: Hex) -> void:
	if _is_on_map_edge(tile):
		add_score(tile, _get_production_amount())