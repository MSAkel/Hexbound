extends Rune

# Triggers the first rune of each segment after it. Requires a first segment tile.
func _on_activate_rune(tile: Hex) -> void:
	var current_index: int = _get_segment_index(tile)
	var to_retrigger: Array[Rune] = []
	for subsequent_segment_index in range(current_index):
		# Postive offset: how many segments after this tile's segment.
		var segment_index_offset := subsequent_segment_index - current_index
		var rune: Rune = _get_first_or_last_rune_in_relative_segment(tile, segment_index_offset, true)
		if rune != null:
			to_retrigger.append(rune)
	queue_rune_triggers(tile, to_retrigger)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var current_index := _get_segment_index(hover_tile)
	var coords: Array[Vector2i] = []
	for subsequent_segment_index in range(current_index):
		var segment_index_offset := subsequent_segment_index - current_index
		var rune := _get_first_or_last_rune_in_relative_segment(
			hover_tile, segment_index_offset, true
		)
		if rune != null:
			coords.append_array(_coords_for_placed_runes(hover_tile, [rune]))
		else:
			var fallback := hover_tile.map.get_first_tile_coords_in_segment(subsequent_segment_index)
			if fallback != Vector2i(-1, -1):
				coords.append(fallback)
	return coords
