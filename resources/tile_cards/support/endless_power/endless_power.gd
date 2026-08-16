extends TileCard

# Empowers a Prod rune for every currently empowered Prod rune
func _on_activate_tile_card(tile: Hex) -> void:
	var prod_runes: Array[TileCard] = _get_all_placed_tile_cards(tile, TileCard.TileCardType.PRODUCER)
	# Track remaining targets so each empowered rune picks a distinct unempowered one
	var unempowered_runes: Array[TileCard] = prod_runes.filter(
		func(prod_rune: TileCard): return not prod_rune.is_empowered
	)
	
	for rune in prod_runes:
		if not rune.is_empowered:
			continue
		if unempowered_runes.is_empty():
			_create_floating_text(tile, "No unempowered runes")
			break
		var target: TileCard = unempowered_runes.pick_random()
		target._empower()
		unempowered_runes.erase(target)
		_create_floating_text(tile, "Empowered %s" % target.name)
