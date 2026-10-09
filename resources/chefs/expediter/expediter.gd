extends ChefCard

## The first Kitchenware in this course's fire order fires twice more, once per Hour.
const EXTRA_FIRES := 2


func on_card_activated(ctx: ChefContext, tile: Hex, card: TileCard) -> void:
	if ctx.hour_state.get("expedited", false) or not ctx.is_on_course(tile):
		return
	if card.type != TileCard.TileCardType.KITCHENWARE:
		return
	var kitchenware := ctx.course_cards(TileCard.TileCardType.KITCHENWARE)
	if kitchenware.is_empty() or kitchenware[0] != card:
		return
	ctx.hour_state["expedited"] = true
	var again: Array[TileCard] = []
	for _i in EXTRA_FIRES:
		again.append(card)
	ctx.queue_triggers(again)
