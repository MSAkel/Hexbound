extends Rune

## Returns rune to hand
func _on_activate_rune(tile: Hex) -> void:
	pass
	
func apply_on_placement(tile: Hex) -> void:
	if tile.active_rune == null:
		return
	
	# Hand cards need a fresh instance without map activation state.
	var hand_copy: Rune = tile.active_rune.duplicate(true)
	hand_copy.activation_count = 0
	hand_copy.is_empowered = false
	hand_copy.is_active = true
	Events.rune_selected.emit(hand_copy)
	tile.remove_rune()
	_create_floating_text(tile, "Returned!")
