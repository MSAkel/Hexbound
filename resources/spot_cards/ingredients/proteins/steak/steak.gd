extends TileCard

## +10 Flavour per Seasoning on this course. Max +40.

const MAX_FLAVOUR := 40


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	var seasoning_count := _effect_preview_cards(tile).size()
	if seasoning_count <= 0:
		return 0.0
	var amount := _get_production_amount() * float(seasoning_count)
	return float(mini(int(round(amount)), MAX_FLAVOUR))


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _producers_by_product(tile, Product.MULTIPLIER, QueryScope.SAME_SEGMENT)
