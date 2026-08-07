extends Rune

# Gains the effect of the last two runes triggered before it
func _on_activate_rune(tile: Hex) -> void:
	var prior_runes := _get_previous_runes_in_trigger_order(tile, 2)
	if prior_runes.is_empty():
		return
	
	# Run each prior rune's effect from this tile without re-triggering them on their hexes.
	var output_scale := _activation_output_scale
	for prior_rune: Rune in prior_runes:
		prior_rune._activation_output_scale = output_scale
		prior_rune._on_activate_rune(tile)
		prior_rune._activation_output_scale = 1.0
