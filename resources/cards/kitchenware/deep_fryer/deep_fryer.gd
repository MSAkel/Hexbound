extends TileCard

## +2 Mult, +1 Mult for each extra trigger it gives. Triggers the Following Ingredient again, twice
## if it is Potato or Chicken (or counts as Potato, e.g. Fry Station's Tempura).
## Fried Meals (Fried Chicken, French Fries, Fritters, Onion Rings) read how many triggers the Deep
## Fryers on their station gave this Hour (hour_prepared_count).

const TARGET_COUNT := 1
const RETRIGGERS := 1
const FAVOURITE_RETRIGGERS := 2
const FAVOURITE_IDS: Array[String] = ["potato", "chicken"]


func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		_pay_kitchenware_mult(tile)
		return
	var given := 0
	for target: TileCard in targets:
		var queued: Array[TileCard] = []
		for _i in _retriggers_for(tile, target):
			queued.append(target)
		if _try_queue_tile_card_triggers(tile, queued):
			_create_fired_floating_text(tile, target)
			given += queued.size()
	_pay_kitchenware_mult(tile, given)


func get_planned_preparations(tile: Hex) -> int:
	var total := 0
	for target: TileCard in _effect_preview_cards(tile):
		total += _retriggers_for(tile, target)
	return total


func _retriggers_for(tile: Hex, target: TileCard) -> int:
	var favourite := target.id in FAVOURITE_IDS or StationManager.counts_as_potato(_hex_for(tile, target), target)
	return FAVOURITE_RETRIGGERS if favourite else RETRIGGERS


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
