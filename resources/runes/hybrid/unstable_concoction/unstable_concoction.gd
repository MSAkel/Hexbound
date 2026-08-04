extends Rune

# Gives 50 - 100 Score, or 10 - 15 Multi or 10 - 20 gold or triggers the two previous runes
func _on_activate_rune(tile: Hex) -> void:
	match randi_range(0, 3):
		0:
			add_score(tile, randi_range(50, 100))
		1:
			add_multiplier(tile, randi_range(10, 15))
		2:
			add_gold(tile, randi_range(10, 20))
		3:
			var prior_runes := get_runes_in_activation_order(tile, 2, true)
			if prior_runes.is_empty():
				return
			queue_rune_triggers(tile, prior_runes)
			create_floating_text(tile, "Trigger runes")
