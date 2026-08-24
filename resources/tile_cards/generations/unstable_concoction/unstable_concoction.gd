extends TileCard

## Gives 100 Energy or 15 Mult or 15 Gold
func _on_activate_tile_card(tile: Hex) -> void:
	match randi_range(0, 3):
		0:
			add_score(tile, 100)
		1:
			add_multiplier(tile, 15)
		2:
			add_gold(tile, 15)
