extends Rune

# +25 score. On the last turn of a round, empowers every Prod rune in its segment
func _on_activate_rune(tile: Hex) -> void:
	add_score(tile, 25)
	# remaining_turns of 1 means this is the final turn of the phase.
	if GameManager.remaining_turns == 1:
		var prod_runes := _get_all_runes_on_same_segment(tile, RuneType.PRODUCER)
		if prod_runes.is_empty():
			return
		for rune in prod_runes:
			rune._empower()
			_create_floating_text(tile, "Empowered %s" % rune.name)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_runes(hover_tile, RuneType.PRODUCER)
