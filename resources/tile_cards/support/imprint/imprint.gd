extends TileCard

## Copies the effects of the two tiles directly before this one. Empty tiles are skipped, not walked past.

func _on_activate_tile_card(tile: Hex) -> void:
	var prior_runes := _get_tile_cards_on_immediately_previous_hexes(tile, 2)
	if prior_runes.is_empty():
		failed_tile_card_text(tile)
		return

	# Replay those effects from this hex. The source tiles are not retriggered.
	# Copied retriggers skip this host, so a prior Break Glass cannot loop Imprint.
	var output_scale := _activation_output_scale
	for prior_rune: TileCard in prior_runes:
		var prior_hex := tile.map.get_hex_for_tile_card(prior_rune)
		if not prior_rune.can_be_triggered_by_other_card(prior_hex):
			continue
		prior_rune._activation_output_scale = output_scale
		prior_rune._on_activate_tile_card(tile)
		prior_rune._activation_output_scale = 1.0


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_immediately_previous_hexes(hover_tile, 2)
