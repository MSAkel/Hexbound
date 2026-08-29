extends TileCard

## Spend 1 Gold to empower a random Downstream Producer on this segment.
func _on_activate_tile_card(tile: Hex) -> void:
	if not GoldManager.can_afford(1):
		_create_floating_text(tile, "Insufficient gold")
		return

	var later_producers := _get_later_tile_cards_on_same_segment(tile, TileCardType.PRODUCER)
	if later_producers.is_empty():
		failed_tile_card_text(tile)
		return

	GoldManager.remove(1)
	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	var target_rune: TileCard = RunRng.pick_random_placed_tile_card(later_producers, rng, tile.map)
	if not _try_empower_tile_card(tile, target_rune):
		failed_tile_card_text(tile)
		return

	_create_floating_text(tile, "Empowered %s" % target_rune.name)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(
		hover_tile,
		_get_later_tile_cards_on_same_segment(hover_tile, TileCardType.PRODUCER)
	)
