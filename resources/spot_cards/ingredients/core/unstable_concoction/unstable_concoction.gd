extends TileCard

## Gives 80 Flavour or 12 Mult or 6 Gold
func _on_activate_tile_card(tile: Hex) -> void:
	match RunRng.create_card_effect_rng(tile, self).randi_range(0, 2):
		0:
			add_score(tile, 80)
		1:
			add_multiplier(tile, 12)
		2:
			add_gold(tile, 6)
