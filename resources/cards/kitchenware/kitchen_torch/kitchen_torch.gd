extends TileCard

## +2 Mult. Garnishes every adjacent Ingredient and Meal.


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	_garnish_targets(tile, _effect_preview_cards(tile))


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_all_adjacent_tile_cards(tile, [TileCardType.INGREDIENT, TileCardType.MEAL])
