extends Rune

# Triggers the next 3 generator runes in the trigger order; output reduced by 20% per jump.
func _on_activate_rune(tile: Hex) -> void:
	var next_generators := _get_next_runes_in_trigger_order(tile, 3, Rune.RuneType.PRODUCER)
	if next_generators.is_empty():
		return
	
	_create_floating_text(tile, "Zap!")
	# 100%, 80%, 64% ... each jump applies another 20% reduction.
	var activation_scales: Array[float] = []
	for i in range(next_generators.size()):
		activation_scales.append(pow(0.8, i))
		
	queue_rune_triggers(tile, next_generators, activation_scales)
