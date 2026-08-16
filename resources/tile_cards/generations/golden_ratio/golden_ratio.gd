extends TileCard

# +1 multiplier for every 1 gold earned this turn
func _on_activate_tile_card(tile: Hex) -> void:
	add_multiplier(tile, GoldManager.earned_this_turn)
