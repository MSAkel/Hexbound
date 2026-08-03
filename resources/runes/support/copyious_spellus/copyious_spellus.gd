extends Rune

# Creates a copy of a rune it is placed on on a tile, the copied rune goes to the hand of the player.
# The modifier card is consumed on placement and does not occupy the tile.
func apply_on_placement(tile: Hex) -> void:
	if tile.active_rune == null:
		return
	
	# Hand cards need a fresh instance without map activation state.
	var hand_copy: Rune = tile.active_rune.duplicate(true)
	hand_copy.activation_count = 0
	hand_copy.is_empowered = false
	hand_copy.is_active = true
	Events.rune_selected.emit(hand_copy)
	create_floating_text(tile, "Copied!")
