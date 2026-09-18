extends TileCard

## +1 additive Mult for every condiment used during this run.


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile, true)


func _effect_amount(_tile: Hex) -> float:
	return _get_production_amount() * float(RunLedger.condiments_used)
