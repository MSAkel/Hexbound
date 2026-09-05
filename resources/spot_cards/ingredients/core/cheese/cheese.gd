extends TileCard

## Gives 40 Flavour or 12 Mult
func _on_activate_tile_card(tile: Hex) -> void:
	match RunRng.create_card_effect_rng(tile, self).randi_range(0, 1):
		0:
			add_score(tile, 40)
		1:
			add_additive_mult(tile, 12)
