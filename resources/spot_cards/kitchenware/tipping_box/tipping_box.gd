extends TileCard

## +2 Flavour for every Gold you have.
func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_treasury_amount())


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _amount_board_chip(_get_treasury_amount())


func _get_treasury_amount() -> int:
	return int(_get_production_amount()) + GoldManager.amount
