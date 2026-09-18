extends TileCard

# +4 Mult increased by 1 for each Mult rune on the same segment
func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	return float(_effect_preview_cards(tile).size()) + _get_production_amount()


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _producers_by_product(tile, Product.MULTIPLIER, QueryScope.SAME_SEGMENT)
