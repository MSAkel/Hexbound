extends TileCard

## +1 Mult. Triggers the Following 2 Ingredients again, twice each if Meat.

const TARGET_COUNT := 2
const RETRIGGERS := 1
const MEAT_RETRIGGERS := 2


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		return
	var queued: Array[TileCard] = []
	for target: TileCard in targets:
		for _i in (MEAT_RETRIGGERS if target.has_ingredient_tag(TAG_MEAT) else RETRIGGERS):
			queued.append(target)
	if _try_queue_tile_card_triggers(tile, queued):
		for target: TileCard in targets:
			_create_fired_floating_text(tile, target)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
