extends Rune

# Retrigger the last rune on each segment prior to this rune
func _on_activate_rune(tile: Hex) -> void:
	var current_index: int = tile.map.get_segment_index(tile.coordinates)
	var to_retrigger: Array[Rune] = []
	for i in range(current_index):
		var rune: Rune = tile.map.get_first_or_last_rune_in_segment(tile, i - current_index, false)
		if rune != null:
			to_retrigger.append(rune)
	queue_rune_triggers(tile, to_retrigger)
