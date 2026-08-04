extends Rune

# +25 score. On the last turn of a round, empowers every Prod rune in its segment
func _on_activate_rune(tile: Hex) -> void:
	add_score(tile, 25)
	if GameManager.current_turn == GameManager.MAX_TURNS_PER_PHASE:
		var prod_runes := get_runes_on_same_segment(tile, RuneType.PRODUCER)
		if prod_runes.is_empty():
			return
		for rune in prod_runes:
			rune.empower()
			create_floating_text(tile, "Empowered %s" % rune.name)
