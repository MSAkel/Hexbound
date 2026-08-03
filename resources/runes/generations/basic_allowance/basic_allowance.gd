extends Rune


# Gain 2 gold
func _on_activate_rune(tile: Hex) -> void:
	GoldManager.add(2)
