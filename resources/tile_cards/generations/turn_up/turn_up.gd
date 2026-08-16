extends TileCard

# Gains Mult equal to the ascending turn number x production amount
func _on_activate_tile_card(tile: Hex) -> void:
	# Use turn number (counts up), not remaining turns (counts down).
	add_multiplier(tile, _get_production_amount() * GameManager.get_turn_number())
