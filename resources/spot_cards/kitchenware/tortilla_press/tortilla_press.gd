extends TileCard

## Fires the first card of each following course. Must sit on a first course spot.
func _on_activate_tile_card(tile: Hex) -> void:
	var current_index: int = _get_segment_index(tile)
	var segment_count := _get_segment_count(tile)
	var to_retrigger: Array[TileCard] = []
	for later_index in range(current_index + 1, segment_count):
		var segment_index_offset := later_index - current_index
		var rune: TileCard = _get_first_or_last_tile_card_in_relative_segment(tile, segment_index_offset, true)
		if rune != null:
			to_retrigger.append(rune)

	_try_queue_tile_card_triggers(tile, to_retrigger)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var current_index := _get_segment_index(hover_tile)
	var segment_count := _get_segment_count(hover_tile)
	var coords: Array[Vector2i] = []
	for later_index in range(current_index + 1, segment_count):
		var segment_index_offset := later_index - current_index
		var rune := _get_first_or_last_tile_card_in_relative_segment(
			hover_tile, segment_index_offset, true
		)
		if rune != null:
			coords.append_array(_coords_for_placed_tile_cards(hover_tile, [rune]))
		else:
			var fallback := hover_tile.map.get_first_tile_coords_in_segment(later_index)
			if fallback != Vector2i(-1, -1):
				coords.append(fallback)
	return coords
