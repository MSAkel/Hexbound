extends Rune

# After every 4 triggers produces 300 score, 20 mult and 15 gold.
func _on_activate_rune(tile: Hex) -> void:
	activation_count += 1
	if activation_count % 4 == 0:
		add_score(tile, 300)
		GameManager.turn_multi += 20
		GoldManager.add(15)
		create_floating_text(tile, "Dividend!")
