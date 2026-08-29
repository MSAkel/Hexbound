extends TileCard

## On the final turn, empower every Downstream Producer on this segment.
func _on_activate_tile_card(tile: Hex) -> void:
	if GameManager.remaining_turns != 1:
		failed_tile_card_text(tile)
		return

	var later_producers := _get_later_tile_cards_on_same_segment(tile, TileCardType.PRODUCER)
	if later_producers.is_empty():
		failed_tile_card_text(tile)
		return

	var empowered_any := false
	for rune in later_producers:
		if not _try_empower_tile_card(tile, rune):
			continue
		empowered_any = true
		_create_floating_text(tile, "Empowered %s" % rune.name)

	if not empowered_any:
		failed_tile_card_text(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(
		hover_tile,
		_get_later_tile_cards_on_same_segment(hover_tile, TileCardType.PRODUCER)
	)
