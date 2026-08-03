extends Rune

# After every 2 triggers, empowers a random prod Rune in its segment.
func _on_activate_rune(tile: Hex) -> void:
	activation_count += 1
	if activation_count == 2:
		var producers := get_runes_on_same_segment(tile, Rune.RuneType.PRODUCER)
		if not producers.is_empty():
			producers.pick_random().empower()
			activation_count = 0
