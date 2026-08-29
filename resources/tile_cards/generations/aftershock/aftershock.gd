extends TileCard
## +10 Energy each time this card triggers this turn.

func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_aftershock_amount())


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _amount_board_chip(_get_aftershock_amount())


func _get_aftershock_amount() -> float:
	# register_tile_card_activation already counted this firing.
	var activations := GameManager.get_tile_card_activation_count_this_turn(self)
	return _get_production_amount() * float(maxi(activations, 1))
