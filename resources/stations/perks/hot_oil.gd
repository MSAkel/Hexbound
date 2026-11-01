extends StationPerk

## Hot Oil: the first Ingredient to trigger on this station each Hour triggers again.


func after_card_triggered(seg: int, tile: Hex, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.INGREDIENT:
		return
	var state := StationManager.get_state(seg)
	if state.get("hour_hot_oil", false):
		return
	state["hour_hot_oil"] = true
	var targets: Array[TileCard] = [card]
	card.queue_tile_card_triggers(tile, targets)
