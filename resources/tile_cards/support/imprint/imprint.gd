extends TileCard

# Gains the effect of the last two runes triggered before it
func _on_activate_tile_card(tile: Hex) -> void:
	var prior_runes := _get_previous_tile_cards_in_trigger_order(tile, 2)
	if prior_runes.is_empty():
		return
	
	# Run each prior rune's effect from this tile without re-triggering them on their hexes.
	var output_scale := _activation_output_scale
	for prior_rune: TileCard in prior_runes:
		prior_rune._activation_output_scale = output_scale
		prior_rune._on_activate_tile_card(tile)
		prior_rune._activation_output_scale = 1.0


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var prior_runes := _get_previous_tile_cards_in_trigger_order(hover_tile, 2)
	return _coords_for_placed_tile_cards(hover_tile, prior_runes)
