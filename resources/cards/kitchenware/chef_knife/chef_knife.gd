extends TileCard

## +2 Mult, +1 Mult for each extra trigger it gives. Triggers the Following Ingredient twice.

const TRIGGERS := 2


func _on_activate_tile_card(tile: Hex) -> void:
	var next_cards := _effect_preview_cards(tile)
	if next_cards.is_empty():
		failed_tile_card_text(tile)
		_pay_kitchenware_mult(tile)
		return
	var target := next_cards[0]
	var queued: Array[TileCard] = []
	for _i in TRIGGERS:
		queued.append(target)
	var given := 0
	if _try_queue_tile_card_triggers(tile, queued):
		_create_fired_floating_text(tile, target)
		given = queued.size()
	_pay_kitchenware_mult(tile, given)


func get_planned_preparations(tile: Hex) -> int:
	return TRIGGERS if not _effect_preview_cards(tile).is_empty() else 0


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, 1, TileCard.PRODUCER_TYPE_FILTER)
