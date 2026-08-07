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
