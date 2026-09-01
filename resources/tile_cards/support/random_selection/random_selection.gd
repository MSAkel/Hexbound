extends TileCard

## Triggers two random cards on Following segments.
func _on_activate_tile_card(tile: Hex) -> void:
	var later_runes := _get_all_tile_cards_on_later_segments(tile)
	if later_runes.is_empty():
		failed_tile_card_text(tile)
		return

	var to_trigger: Array[TileCard] = []
	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	for _i in range(2):
		to_trigger.append(RunRng.pick_random_placed_tile_card(later_runes, rng, tile.map))

	_try_queue_tile_card_triggers(tile, to_trigger)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_all_tile_cards_on_later_segments(hover_tile))
