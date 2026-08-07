extends Rune

func _on_activate_rune(tile: Hex) -> void:
	# Basic runes generate score when triggered at end of turn
	add_score(tile, base_production_amount)
