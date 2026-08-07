extends Rune

# +25 score. On the last turn of a round, empowers every Prod rune in its segment
func _on_activate_rune(tile: Hex) -> void:
	add_score(tile, 25)
	if GameManager.current_turn == GameManager.get_max_turns_per_phase():
		var prod_runes := _get_all_runes_on_same_segment(tile, RuneType.PRODUCER)
		if prod_runes.is_empty():
			return
		for rune in prod_runes:
			rune._empower()
			_create_floating_text(tile, "Empowered %s" % rune.name)
