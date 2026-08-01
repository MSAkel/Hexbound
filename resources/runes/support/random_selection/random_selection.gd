extends Rune

# Triggers two random runes
func _on_activate_rune(tile: Hex) -> void:
	var candidates := get_all_placed_runes(tile)
	candidates.erase(self)
	if candidates.is_empty():
		return
	
	var picked: Array[Rune] = []
	var pool := candidates.duplicate()
	var pick_count := mini(2, pool.size())
	for _i in range(pick_count):
		var choice: Rune = pool.pick_random()
		picked.append(choice)
		pool.erase(choice)
	
	queue_rune_triggers(tile, picked)
