extends TileCard

## +15 Flavour per Following adjacent Flavour card.
func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	var neighboring := _effect_preview_cards(tile)
	var flavour_to_add := _get_production_amount() * float(neighboring.size())
	return flavour_to_add


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _producers_by_product(tile, Product.FLAVOUR, QueryScope.FOLLOWING_ADJACENT)
