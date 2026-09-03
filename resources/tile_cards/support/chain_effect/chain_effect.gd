extends TileCard

# Triggers the next 3 generator runes in the trigger order. Output reduced by 20% per jump.
func _on_activate_tile_card(tile: Hex) -> void:
	var next_generators := _get_next_tile_cards_in_trigger_order(tile, 3, TileCard.PRODUCER_TYPE_FILTER)
	if next_generators.is_empty():
		failed_tile_card_text(tile)
		return

	_create_floating_text(tile, "Zap!")
	# 100%, 80%, 64% ... each jump applies another 20% reduction.
	var activation_scales: Array[float] = []
	for i in range(next_generators.size()):
		activation_scales.append(pow(0.8, i))

	_try_queue_tile_card_triggers(tile, next_generators, activation_scales)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var next_generators := _get_next_tile_cards_in_trigger_order(
		hover_tile, 3, TileCard.PRODUCER_TYPE_FILTER
	)
	return _coords_for_placed_tile_cards(hover_tile, next_generators)
