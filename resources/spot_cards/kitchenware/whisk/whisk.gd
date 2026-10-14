extends TileCard

## Garnishes the Following Ingredient in fire order.
func _on_activate_tile_card(tile: Hex) -> void:
	var next_producers := _effect_preview_cards(tile)
	if next_producers.is_empty():
		failed_tile_card_text(tile)
		return

	var target := next_producers[0]
	if not _try_garnish_tile_card(tile, target):
		failed_tile_card_text(tile)
		return

	_create_garnish_floating_text(tile, target)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, 1, TileCard.PRODUCER_TYPE_FILTER)
