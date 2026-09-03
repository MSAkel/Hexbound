extends TileCard

const DESTROY_CHANCE_PER_FOLLOWING := 0.10

## Fire adjacent Following Ingredients. 10% spoil chance per Following adjacent Ingredient.
func _on_activate_tile_card(tile: Hex) -> void:
	var following_producers := _get_following_adjacent_tile_cards(tile, TileCard.PRODUCER_TYPE_FILTER)
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


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(
		hover_tile,
		_get_following_adjacent_tile_cards(hover_tile, TileCard.PRODUCER_TYPE_FILTER)
	)
