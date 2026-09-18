extends TileCard

const DESTROY_CHANCE_PER_FOLLOWING := 0.10

## Fire adjacent Following Ingredients. 10% spoil chance per Following adjacent Ingredient.
## fires → spoils → adjacent Ingredients fire.
func _on_activate_tile_card(tile: Hex) -> void:
	var following_producers := _effect_preview_cards(tile)
	if following_producers.is_empty():
		failed_tile_card_text(tile)
		return

	if not _try_queue_tile_card_triggers(tile, following_producers):
		return

	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	for _i in range(following_producers.size()):
		if rng.randf() < DESTROY_CHANCE_PER_FOLLOWING:
			_destroy_placed_tile_card(tile, self)
			AudioManager.play_sfx(UISounds.SPOIL_BREAK)
			break


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_following_adjacent_tile_cards(tile, TileCard.PRODUCER_TYPE_FILTER)
