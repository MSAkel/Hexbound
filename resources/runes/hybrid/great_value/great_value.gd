extends Rune

# Spends 1 gold to empower a random prod rune in its segment. can be triggered more than once
func _on_activate_rune(tile: Hex) -> void:
	if not GoldManager.can_afford(1):
		create_floating_text(tile, "Insufficient gold")
		return

	GoldManager.remove(1)
	
	var prod_runes := get_runes_on_same_segment(tile, RuneType.PRODUCER)
	if prod_runes.is_empty():
		create_floating_text(tile, "No effect")
		return
	
	var target_rune : Rune = prod_runes.pick_random()
	target_rune.empower()
	create_floating_text(tile, "Empowered %s" % target_rune.name)
