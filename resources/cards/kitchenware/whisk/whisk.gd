extends TileCard

## +2 Mult, +1 Mult for each Garnish it gives. Garnishes the Following 2 Ingredients.

const TARGET_COUNT := 2


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile, _garnish_targets(tile, _effect_preview_cards(tile)))


func get_planned_preparations(tile: Hex) -> int:
	return _effect_preview_cards(tile).size()


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
