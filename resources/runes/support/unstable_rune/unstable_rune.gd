extends Rune

const DESTROY_CHANCE_PER_ADJACENT := 0.15

# Triggers adjacent prod runes, starting from the one next in trigger order. There is a 15% chance that this rune will be destroyed for every adjacent rune
func _on_activate_rune(tile: Hex) -> void:
	var adjacent_producers := _get_adjacent_producers_from_trigger_order(tile)
	if adjacent_producers.is_empty():
		return
	
	queue_rune_triggers(tile, adjacent_producers)
	
	# Each adjacent producer rolled independently; one failed roll destroys this rune.
	for _i in range(adjacent_producers.size()):
		if randf() < DESTROY_CHANCE_PER_ADJACENT:
			_destroy_placed_rune(tile, self)
			AudioManager.play_ui_sound(UISounds.RUNE_BREAK)
			break


# Adjacent producers in trigger order, rotated to start at the next rune in sequence.
func _get_adjacent_producers_from_trigger_order(tile: Hex) -> Array[Rune]:
	var ordered := _get_all_adjacent_runes_in_trigger_order(tile, Rune.RuneType.PRODUCER)
	if ordered.is_empty():
		return ordered
	
	var hexes := tile.map.get_hexes_in_trigger_order()
	var self_index := hexes.find(tile)
	var start_index := 0
	
	var next_rune := _get_next_rune_in_trigger_order(tile)
	if next_rune != null and next_rune in ordered:
		start_index = ordered.find(next_rune)
	else:
		for i in range(ordered.size()):
			var producer_hex := tile.map.get_hex_for_rune(ordered[i])
			if hexes.find(producer_hex) > self_index:
				start_index = i
				break
	
	var rotated: Array[Rune] = []
	for i in range(ordered.size()):
		rotated.append(ordered[(start_index + i) % ordered.size()])
	return rotated
