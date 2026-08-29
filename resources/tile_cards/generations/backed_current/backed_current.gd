extends TileCard
## +20 Energy. If the previous card in trigger order is a Support, retrigger this card once.

func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())
	# Only self-retrigger on the first firing this turn so Overdrive cannot loop this forever.
	if GameManager.get_tile_card_activation_count_this_turn(self) != 1:
		return
	var previous := _get_previous_tile_cards_in_trigger_order(tile, 1)
	if previous.is_empty() or previous[0].type != TileCardType.SUPPORT:
		return
	_try_queue_tile_card_triggers(tile, [self])
