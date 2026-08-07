extends Rune

# Triggers two random runes on a different segment
func _on_activate_rune(tile: Hex) -> void:
	var other_segments_runes := _get_all_runes_on_other_segments(tile)
	if other_segments_runes.is_empty():
		return
	
	var to_trigger: Array[Rune] = []
	for _i in range(2):
		to_trigger.append(other_segments_runes.pick_random())
	
	queue_rune_triggers(tile, to_trigger)
	
