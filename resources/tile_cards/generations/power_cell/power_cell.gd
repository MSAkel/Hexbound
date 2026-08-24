extends TileCard

func _on_activate_tile_card(tile: Hex) -> void:
	# Basic runes generate score when triggered at end of turn
	add_score(tile, _get_production_amount())
