extends TileCard

# Gives 50 - 100 Score, or 10 - 15 Multi or 10 - 20 gold or triggers the two previous runes
func _on_activate_tile_card(tile: Hex) -> void:
	match randi_range(0, 3):
		0:
			add_score(tile, randi_range(50, 100))
		1:
			add_multiplier(tile, randi_range(10, 15))
		2:
			add_gold(tile, randi_range(10, 20))
		3:
			var prior_runes := _get_previous_tile_cards_in_trigger_order(tile, 2)
			if prior_runes.is_empty():
				return
			queue_tile_card_triggers(tile, prior_runes)
			_create_floating_text(tile, "Trigger runes")


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var prior_runes := _get_previous_tile_cards_in_trigger_order(hover_tile, 2)
	return _coords_for_placed_tile_cards(hover_tile, prior_runes)
