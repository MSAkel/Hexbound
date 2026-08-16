extends TileCard

# After every 2 triggers, empowers a random prod TileCard in its segment.
func _on_activate_tile_card(tile: Hex) -> void:
	activation_count += 1
	if activation_count == 2:
		var producers := _get_all_tile_cards_on_same_segment(tile, TileCard.TileCardType.PRODUCER)
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


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_tile_cards(hover_tile, TileCardType.PRODUCER)
