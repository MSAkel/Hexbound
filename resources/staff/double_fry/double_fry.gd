extends StaffCard

## Fry Station partner: the Deep Fryer's own target fires a second time.
const DEEP_FRYER_ID := "deep_fryer"


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if ctx.is_staff_caused_activation() or not ctx.is_on_station(tile):
		return
	if card.type != TileCard.TileCardType.INGREDIENT or card not in _targets(ctx):
		return
	var done: Dictionary = ctx.hour_state.get_or_add("done", {})
	if done.has(card):
		return
	done[card] = true
	var again: Array[TileCard] = [card]
	ctx.queue_triggers(again)


## The first Ingredient after each Deep Fryer, in trigger order.
func _targets(ctx: StaffContext) -> Array[TileCard]:
	var targets: Array[TileCard] = []
	var after_fryer := false
	for card: TileCard in ctx.station_cards():
		if card.type == TileCard.TileCardType.KITCHENWARE and card.id == DEEP_FRYER_ID:
			after_fryer = true
		elif after_fryer and card.type == TileCard.TileCardType.INGREDIENT:
			targets.append(card)
			after_fryer = false
	return targets
