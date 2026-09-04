extends TileCard

## Fire one random adjacent Following card.
func _on_activate_tile_card(tile: Hex) -> void:
	var following_cards := _get_following_adjacent_tile_cards(tile)
	if following_cards.is_empty():
		failed_tile_card_text(tile)
		return

	var target := _pick_random_placed_tile_card(tile, following_cards, _effect_rng(tile))
	if target == null:
		failed_tile_card_text(tile)
		return

	if not _try_queue_tile_card_triggers(tile, [target]):
		return

	_create_fired_floating_text(tile, target)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	# Every occupied adjacent Following hex is a possible roll target.
	return _coords_for_placed_tile_cards(hover_tile, _get_following_adjacent_tile_cards(hover_tile))
