extends TileCard

## Fires two random cards on following courses.
func _on_activate_tile_card(tile: Hex) -> void:
	var later_runes := _effect_preview_cards(tile)
	if later_runes.is_empty():
		failed_tile_card_text(tile)
		return

	var to_trigger: Array[TileCard] = []
	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	for _i in range(2):
		to_trigger.append(RunRng.pick_random_placed_tile_card(later_runes, rng, tile.map))

	_try_queue_tile_card_triggers(tile, to_trigger)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_all_tile_cards_on_later_segments(tile)
