extends TileCard

## +3 Mult. Triggers the Following Ingredient twice.


func _init() -> void:
	single_activation_per_turn = true


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	var next_cards := _effect_preview_cards(tile)
	if next_cards.is_empty():
		failed_tile_card_text(tile)
		return
	var target := next_cards[0]
	if _try_queue_tile_card_triggers(tile, [target, target]):
		_create_fired_floating_text(tile, target)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, 1, TileCard.PRODUCER_TYPE_FILTER)
