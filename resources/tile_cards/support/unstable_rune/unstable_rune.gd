extends TileCard

const DESTROY_CHANCE_PER_DOWNSTREAM := 0.10

## Trigger adjacent Downstream Producers. 10% break chance per adjacent Downstream Producer. No wrap.
func _on_activate_tile_card(tile: Hex) -> void:
	var downstream_producers := _get_downstream_adjacent_tile_cards(tile, TileCard.TileCardType.PRODUCER)
	if downstream_producers.is_empty():
		failed_tile_card_text(tile)
		return

	if not _try_queue_tile_card_triggers(tile, downstream_producers):
		return

	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	for _i in range(downstream_producers.size()):
		if rng.randf() < DESTROY_CHANCE_PER_DOWNSTREAM:
			_destroy_placed_tile_card(tile, self)
			AudioManager.play_sfx(UISounds.RUNE_BREAK)
			break


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(
		hover_tile,
		_get_downstream_adjacent_tile_cards(hover_tile, TileCardType.PRODUCER)
	)
