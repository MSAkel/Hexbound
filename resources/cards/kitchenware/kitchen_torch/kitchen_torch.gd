extends TileCard

## +10 Flavour. Garnishes the Meal next to it (every adjacent Meal).


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_output(tile, _garnish_targets(tile, _effect_preview_cards(tile)))


func get_planned_preparations(tile: Hex) -> int:
	return _effect_preview_cards(tile).size()


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_all_adjacent_tile_cards(tile, [TileCardType.MEAL])
