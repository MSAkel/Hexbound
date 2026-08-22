extends TileCard

## After 3 retriggers in this segment, empower the next Producer. Once per turn
const SEGMENT_RETRIGGERS_NEEDED := 3

func _on_activate_tile_card(tile: Hex) -> void:
	# Only counts activations beyond each card's first trigger this turn.
	var retrigger_count := _get_segment_retrigger_count_this_turn(tile)
	if retrigger_count < SEGMENT_RETRIGGERS_NEEDED:
		_create_floating_text(tile, "%d/%d" % [retrigger_count, SEGMENT_RETRIGGERS_NEEDED])
		return

	var next_producers := _get_next_tile_cards_in_trigger_order(
		tile, 1, TileCard.TileCardType.PRODUCER
	)
	if next_producers.is_empty():
		failed_tile_card_text(tile)
		return

	var target := next_producers[0]
	target._empower()
	_create_floating_text(tile, "Empowered: %s" % target.name)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var next_producers := _get_next_tile_cards_in_trigger_order(
		hover_tile, 1, TileCardType.PRODUCER
	)
	return _coords_for_placed_tile_cards(hover_tile, next_producers)
