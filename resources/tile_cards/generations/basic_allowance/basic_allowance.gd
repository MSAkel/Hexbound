extends TileCard


# Gain 1 gold per activation, including bonus production from other cards.
func _on_activate_tile_card(tile: Hex) -> void:
	add_gold(tile, _get_production_amount())
