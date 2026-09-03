extends TileCard
## +80 Flavour. Must sit on a 1-spot course.

func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())
