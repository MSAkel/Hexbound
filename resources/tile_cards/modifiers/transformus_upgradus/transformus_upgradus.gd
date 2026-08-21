extends TileCard
## Transforms a played card into a random card of a higher rarity


func apply_on_placement(tile: Hex) -> void:
	var target := tile.active_tile_card
	if target == null:
		return

	if target.rarity >= TileCardRarity.RARE:
		failed_tile_card_text(tile)
		return

	var higher_rarity := (target.rarity + 1) as TileCardRarity
	var replacement := _pick_random_placeable_tile_card(higher_rarity)
	if replacement == null:
		failed_tile_card_text(tile)
		return

	_replace_placed_tile_card(tile, replacement)
	_create_floating_text(tile, "Upgraded!")
