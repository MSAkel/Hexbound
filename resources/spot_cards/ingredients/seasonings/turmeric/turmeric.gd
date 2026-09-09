extends TileCard

## +1 additive Mult for every condiment used during this run.


func _on_activate_tile_card(tile: Hex) -> void:
	if is_zero_approx(_effect_amount(tile)):
		failed_tile_card_text(tile)
		return
	_pay_effect_amount(tile)


func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount() * float(RunLedger.condiments_used)
