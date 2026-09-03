extends TileCard


func _on_activate_tile_card(_tile: Hex) -> void:
	pass

# Creates a copy of a rune it is placed on on a tile, the copied rune goes to the hand of the player.
# The modifier card is consumed on placement and does not occupy the tile.
func apply_on_placement(tile: Hex) -> void:
	if tile.active_tile_card == null:
		return
	
	# Hand cards need a fresh instance without map activation state.
	var hand_copy: TileCard = tile.active_tile_card.duplicate(true)
	hand_copy.activation_count = 0
	hand_copy.is_empowered = false
	hand_copy.is_active = true
	EventBus.tile_card_selected.emit(hand_copy)
	_create_floating_text(tile, "Copied!")
