extends TileCard

## +2 Mult. Garnishes the Following 2 Ingredients.

const TARGET_COUNT := 2


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	_garnish_targets(tile, _effect_preview_cards(tile))


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
