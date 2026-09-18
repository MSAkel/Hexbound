extends TileCard

## +1 additive Mult for every completed Hour in this run.


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile, true)


func get_board_chip(tile: Hex = null) -> Dictionary:
	var amount := _effect_amount(tile)
	# Outside a run, show the per-Hour rate instead of an empty chip.
	if tile == null and is_zero_approx(amount):
		amount = _get_production_amount()
	return _amount_board_chip_float(amount, ICON_MULT)


func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount() * float(GameManager.get_passed_hour_count())
