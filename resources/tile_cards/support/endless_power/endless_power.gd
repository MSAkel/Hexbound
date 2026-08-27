extends TileCard

# Empowers a Prod rune for every currently empowered Prod rune
func _on_activate_tile_card(tile: Hex) -> void:
	var prod_runes: Array[TileCard] = _get_all_placed_tile_cards(tile, TileCard.TileCardType.PRODUCER)
	var empowered_sources: Array[TileCard] = []
	for rune in prod_runes:
		if rune.is_empowered:
			empowered_sources.append(rune)

	var unempowered_runes: Array[TileCard] = []
	for rune in prod_runes:
		if rune.is_empowered:
			continue
		if _is_triggerable_tile_card(tile, rune):
			unempowered_runes.append(rune)

	if empowered_sources.is_empty() or unempowered_runes.is_empty():
		failed_tile_card_text(tile)
		return

	for rune in empowered_sources:
		if unempowered_runes.is_empty():
			failed_tile_card_text(tile)
			return

		var target: TileCard = unempowered_runes.pick_random()
		if not _try_empower_tile_card(tile, target):
			failed_tile_card_text(tile)
			return

		unempowered_runes.erase(target)
		_create_floating_text(tile, "Empowered %s" % target.name)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var prod_runes: Array[TileCard] = _get_all_placed_tile_cards(hover_tile, TileCardType.PRODUCER)
	var targets: Array[TileCard] = []
	for prod_rune: TileCard in prod_runes:
		if prod_rune.is_empowered:
			continue
		if _is_triggerable_tile_card(hover_tile, prod_rune):
			targets.append(prod_rune)
	return _coords_for_placed_tile_cards(hover_tile, targets)
