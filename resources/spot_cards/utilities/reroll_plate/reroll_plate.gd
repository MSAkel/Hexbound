extends TileCard
## Transforms a played card into another card of the same rarity

func apply_on_placement(tile: Hex) -> void:
	var target := tile.active_tile_card
	if target == null:
		return

	# exclude_id keeps the roll from returning the same card template.
	var replacement := _pick_random_placeable_tile_card(
		target.rarity,
		target.id,
		RunRng.create_card_effect_rng(tile, self, "transform")
	)
	if replacement == null:
		failed_tile_card_text(tile)
		return

	_replace_placed_tile_card(tile, replacement)
	_create_floating_text(tile, "Transformed!")
