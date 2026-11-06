extends TileCard

## +2 Mult, +1 Mult for each extra trigger it gives. Triggers the Following 2 Ingredients again,
## twice each if Meat.

const TARGET_COUNT := 2
const RETRIGGERS := 1
const MEAT_RETRIGGERS := 2


func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		_pay_kitchenware_mult(tile)
		return
	var queued := _queued_triggers(targets)
	var given := 0
	if _try_queue_tile_card_triggers(tile, queued):
		for target: TileCard in targets:
			_create_fired_floating_text(tile, target)
		given = queued.size()
	_pay_kitchenware_mult(tile, given)


func get_planned_preparations(tile: Hex) -> int:
	return _queued_triggers(_effect_preview_cards(tile)).size()


func _queued_triggers(targets: Array[TileCard]) -> Array[TileCard]:
	var queued: Array[TileCard] = []
	for target: TileCard in targets:
		for _i in (MEAT_RETRIGGERS if target.has_ingredient_tag(TAG_MEAT) else RETRIGGERS):
			queued.append(target)
	return queued


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
