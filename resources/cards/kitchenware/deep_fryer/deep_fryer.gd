extends TileCard

## +2 Mult, +1 Mult for each extra trigger it gives. Triggers the Ingredients on both sides of it on
## its Station again: the nearest one before it and the nearest one after it. Tempura (Fry Station)
## adds one more trigger for Seafood and Vegetables.
## Fried Meals (Fried Chicken, French Fries, Fritters, Onion Rings) read how many triggers the Deep
## Fryers on their station gave this Hour (hour_prepared_count).

const RETRIGGERS := 1


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
	var extra := 1 if StationManager.gets_extra_fryer_trigger(_hex_for(tile, target), target) else 0
	return RETRIGGERS + extra


## The nearest Ingredient before it and the nearest after it, both on its own Station.
func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	var targets := board.previous_ingredients_on_station(tile, 1)
	targets.append_array(board.next_ingredients_on_station(tile, 1))
	return targets
