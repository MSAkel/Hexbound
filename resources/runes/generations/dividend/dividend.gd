extends Rune

# After every 4 triggers produces 300 score, 20 mult and 15 gold.
func _on_activate_rune(tile: Hex) -> void:
	activation_count += 1
	if activation_count % 4 == 0:
		add_score(tile, 300)
		add_multiplier(tile, 20)
		add_gold(tile, 15)
		_create_floating_text(tile, "Dividend!")
