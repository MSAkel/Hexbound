extends Rune

# Empowers a Prod rune for every currently empowered Prod rune
func _on_activate_rune(tile: Hex) -> void:
	var prod_runes: Array[Rune] = _get_all_placed_runes(tile, Rune.RuneType.PRODUCER)
	# Track remaining targets so each empowered rune picks a distinct unempowered one
	var unempowered_runes: Array[Rune] = prod_runes.filter(
		func(prod_rune: Rune): return not prod_rune.is_empowered
	)
	
	for rune in prod_runes:
		if not rune.is_empowered:
			continue
		if unempowered_runes.is_empty():
			_create_floating_text(tile, "No unempowered runes")
			break
		var target: Rune = unempowered_runes.pick_random()
		target._empower()
		unempowered_runes.erase(target)
		_create_floating_text(tile, "Empowered %s" % target.name)
