extends Rune

# After every 2 triggers, empowers a random prod Rune in its segment.
func _on_activate_rune(tile: Hex) -> void:
	activation_count += 1
	if activation_count == 2:
		var producers := _get_all_runes_on_same_segment(tile, Rune.RuneType.PRODUCER)
		if not producers.is_empty():
			var selected_rune = producers.pick_random()	
			selected_rune._empower()
			activation_count = 0
			_create_floating_text(tile, "Empowered: %s" % selected_rune.name)
		else:
			# Reset counter if no producers are on the segment
			_create_floating_text(tile, "Failed")
			activation_count = 0
	else:
		_create_floating_text(tile, "+1 Catalyst")
