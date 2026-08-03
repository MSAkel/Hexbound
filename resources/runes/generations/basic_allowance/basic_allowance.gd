extends Rune


# Gain 2 gold
func _on_activate_rune(tile: Hex) -> void:
	add_gold(tile, 2)
