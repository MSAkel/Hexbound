extends TileCard

# +25 Energy. On the last turn of a round, empowers every Prod rune in its segment
func _on_activate_tile_card(tile: Hex) -> void:
	# remaining_turns of 1 means this is the final turn of the round.
	if GameManager.remaining_turns != 1:
		failed_tile_card_text(tile)
		return

	var prod_runes := _get_all_tile_cards_on_same_segment(tile, TileCardType.PRODUCER)
	if prod_runes.is_empty():
		failed_tile_card_text(tile)
		return

	var empowered_any := false
	for rune in prod_runes:
		if not _try_empower_tile_card(tile, rune):
			continue
		empowered_any = true
		_create_floating_text(tile, "Empowered %s" % rune.name)

	if not empowered_any:
		failed_tile_card_text(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_tile_cards(hover_tile, TileCardType.PRODUCER)
