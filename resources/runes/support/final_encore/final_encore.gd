extends Rune

# Triggers the last rune of each segment prior to it. Requires a last segment tile.
func _on_activate_rune(tile: Hex) -> void:
	var current_index: int = _get_segment_index(tile)
	var to_retrigger: Array[Rune] = []
	for prior_segment_index in range(current_index):
		# Negative offset: how many segments before this tile's segment.
		var segment_index_offset := prior_segment_index - current_index
		var rune: Rune = _get_first_or_last_rune_in_relative_segment(tile, segment_index_offset, false)
		if rune != null:
			to_retrigger.append(rune)
	queue_rune_triggers(tile, to_retrigger)
