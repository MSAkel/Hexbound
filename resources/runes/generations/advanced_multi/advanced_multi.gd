extends Rune

# +3 multi for each adjacent score rune. +15 multi if all adjacent tiles are score rune
func _on_activate_rune(_tile: Hex) -> void:
	var adjacent_generators_count = get_occupied_adjacent_count(_tile, Rune.RuneType.GENERATION)
	if adjacent_generators_count > 0:
		for i in range(adjacent_generators_count):
			GameManager.turn_multi += 3
		if adjacent_generators_count == 5:
			GameManager.turn_multi += 15
