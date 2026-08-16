extends TileCard

# Triggers two random runes on a different segment
func _on_activate_tile_card(tile: Hex) -> void:
	var other_segments_runes := _get_all_tile_cards_on_other_segments(tile)
	if other_segments_runes.is_empty():
		return
	
	var to_trigger: Array[TileCard] = []
	for _i in range(2):
		to_trigger.append(other_segments_runes.pick_random())
	
	queue_tile_card_triggers(tile, to_trigger)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_all_tile_cards_on_other_segments(hover_tile))
