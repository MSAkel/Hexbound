extends TileCard

## +8 Flavour per adjacent Seasoning.
func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	return _get_production_amount() * float(_effect_preview_cards(tile).size())


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _producers_by_product(tile, Product.MULTIPLIER, QueryScope.ADJACENT)
