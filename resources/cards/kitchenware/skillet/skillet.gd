extends TileCard

## +2 Mult, +1 Mult for each extra trigger it gives. Triggers the Following 2 Ingredients again.

const TARGET_COUNT := 2


func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		_pay_kitchenware_mult(tile)
		return
	var given := 0
	if _try_queue_tile_card_triggers(tile, targets.duplicate()):
		for target: TileCard in targets:
			_create_fired_floating_text(tile, target)
		given = targets.size()
	_pay_kitchenware_mult(tile, given)


func get_planned_preparations(tile: Hex) -> int:
	return _effect_preview_cards(tile).size()


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
