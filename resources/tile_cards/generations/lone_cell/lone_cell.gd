extends TileCard
## +80 Energy. Must sit on a 1-tile segment.

func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())
