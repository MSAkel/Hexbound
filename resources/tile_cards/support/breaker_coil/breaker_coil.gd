extends TileCard
## If a card has broken on this segment this turn, retrigger the next Producer.

func _on_activate_tile_card(tile: Hex) -> void:
	if tile.map.get_segment_breaks(_get_segment_index(tile)) <= 0:
		failed_tile_card_text(tile)
		return
	var next_producers := _get_next_tile_cards_in_trigger_order(tile, 1, TileCard.PRODUCER_TYPE_FILTER)
	if next_producers.is_empty():
		failed_tile_card_text(tile)
		return
	_try_queue_tile_card_triggers(tile, next_producers)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(
		hover_tile,
		_get_next_tile_cards_in_trigger_order(hover_tile, 1, TileCard.PRODUCER_TYPE_FILTER)
	)
