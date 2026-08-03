extends Rune

# Gains the effect of the last two runes triggered before it
func _on_activate_rune(tile: Hex) -> void:
	var prior_runes := get_runes_in_activation_order(tile, 2, true)
	if prior_runes.is_empty():
		return
	
	queue_rune_triggers(tile, prior_runes)
