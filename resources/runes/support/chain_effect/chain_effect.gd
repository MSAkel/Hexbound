extends Rune

# Triggers the next 3 generator runes in the trigger order, generated points reduced by 20% per jump
func _on_activate_rune(tile: Hex) -> void:
	var next_generators := get_runes_in_activation_order(tile, 3, false, Rune.RuneType.PRODUCER)
	if next_generators.is_empty():
		return
	
	# 100%, 80%, 64% ... each jump applies another 20% reduction.
	var score_multipliers: Array[float] = []
	for i in range(next_generators.size()):
		score_multipliers.append(pow(0.8, i))
	
	queue_rune_triggers(tile, next_generators, score_multipliers)
