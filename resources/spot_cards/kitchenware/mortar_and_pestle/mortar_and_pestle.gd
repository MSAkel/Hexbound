extends TileCard

## Copies the effects of the two spots directly before this one. Empty spots are skipped, not walked past.

func _on_activate_tile_card(tile: Hex) -> void:
	var prior_hexes := _get_immediately_previous_hexes(tile, 2)
	var copied_any := false
	for prior_hex: Hex in prior_hexes:
		var prior_rune := prior_hex.active_tile_card
		if prior_rune == null:
			continue
		copied_any = true
		# Replay those effects from this hex. The source tiles are not retriggered.
		# Copied retriggers skip this host, so a prior Break Glass cannot loop Imprint.
		if not prior_rune.can_be_triggered_by_other_card(prior_hex):
			continue
		_run_copied_activation(prior_rune, tile)

	if not copied_any:
		failed_tile_card_text(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_immediately_previous_hexes(hover_tile, 2)
