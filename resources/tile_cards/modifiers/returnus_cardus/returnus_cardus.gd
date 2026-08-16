extends TileCard

## Returns rune to hand
func _on_activate_tile_card(tile: Hex) -> void:
	pass
	
func apply_on_placement(tile: Hex) -> void:
	if tile.active_tile_card == null:
		return
	
	# Hand cards need a fresh instance without map activation state.
	var hand_copy: TileCard = tile.active_tile_card.duplicate(true)
	hand_copy.activation_count = 0
	hand_copy.is_empowered = false
	hand_copy.is_active = true
	EventBus.tile_card_selected.emit(hand_copy)
	tile.remove_tile_card()
	_create_floating_text(tile, "Returned!")
