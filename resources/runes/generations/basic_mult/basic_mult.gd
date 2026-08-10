extends Rune

func _on_activate_rune(tile: Hex) -> void:
	add_multiplier(tile, _get_production_amount())
