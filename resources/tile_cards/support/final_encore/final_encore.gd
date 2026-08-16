extends TileCard

# Triggers the last rune of each segment prior to it. Requires a last segment tile.
func _on_activate_tile_card(tile: Hex) -> void:
	var current_index: int = _get_segment_index(tile)
	var to_retrigger: Array[TileCard] = []
	for prior_segment_index in range(current_index):
		# Negative offset: how many segments before this tile's segment.
		var segment_index_offset := prior_segment_index - current_index
		var rune: TileCard = _get_first_or_last_tile_card_in_relative_segment(tile, segment_index_offset, false)
		if rune != null:
			to_retrigger.append(rune)
	queue_tile_card_triggers(tile, to_retrigger)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var current_index := _get_segment_index(hover_tile)
	var coords: Array[Vector2i] = []
	for prior_segment_index in range(current_index):
		var segment_index_offset := prior_segment_index - current_index
		var rune := _get_first_or_last_tile_card_in_relative_segment(
			hover_tile, segment_index_offset, false
		)
		if rune != null:
			coords.append_array(_coords_for_placed_tile_cards(hover_tile, [rune]))
		else:
			var fallback := hover_tile.map.get_last_tile_coords_in_segment(prior_segment_index)
			if fallback != Vector2i(-1, -1):
				coords.append(fallback)
	return coords
