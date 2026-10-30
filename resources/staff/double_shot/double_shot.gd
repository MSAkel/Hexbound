extends StaffCard

## Beverages on this station may fire a second time.
const REPEAT_ODDS := 5


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	# A repeat this staff member caused does not roll again.
	if ctx.is_staff_caused_activation() or not ctx.is_on_station(tile):
		return
	if not card.has_ingredient_tag(TileCard.TAG_BEVERAGE):
		return
	if ctx.rng("beverage").randi_range(1, REPEAT_ODDS) != 1:
		return
	var again: Array[TileCard] = [card]
	ctx.queue_triggers(again)
