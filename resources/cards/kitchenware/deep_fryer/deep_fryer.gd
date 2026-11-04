extends TileCard

## +2 Mult. Triggers the Following Ingredient again, twice if it is Potato or Chicken
## (or counts as Potato, e.g. Fry Station's Tempura).

const TARGET_COUNT := 1
const RETRIGGERS := 1
const FAVOURITE_RETRIGGERS := 2
const FAVOURITE_IDS: Array[String] = ["potato", "chicken"]


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		return
	for target: TileCard in targets:
		var favourite := target.id in FAVOURITE_IDS or StationManager.counts_as_potato(_hex_for(tile, target), target)
		var queued: Array[TileCard] = []
		for _i in (FAVOURITE_RETRIGGERS if favourite else RETRIGGERS):
			queued.append(target)
		if _try_queue_tile_card_triggers(tile, queued):
			_create_fired_floating_text(tile, target)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
