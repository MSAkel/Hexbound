extends Rune

func _on_activate_rune(tile: Hex) -> void:
	add_multiplier(tile, base_production_amount)
