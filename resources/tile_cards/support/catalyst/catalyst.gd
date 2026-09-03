extends TileCard

## Empowers the next Following Producer in trigger order.
func _on_activate_tile_card(tile: Hex) -> void:
	var next_producers := _get_next_tile_cards_in_trigger_order(
		tile, 1, TileCard.PRODUCER_TYPE_FILTER
	)
	if next_producers.is_empty():
		failed_tile_card_text(tile)
		return

	var target := next_producers[0]
	if not _try_empower_tile_card(tile, target):
		failed_tile_card_text(tile)
		return

	_create_floating_text(tile, "Empowered: %s" % target.name)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var next_producers := _get_next_tile_cards_in_trigger_order(
		hover_tile, 1, TileCard.PRODUCER_TYPE_FILTER
	)
	return _coords_for_placed_tile_cards(hover_tile, next_producers)
