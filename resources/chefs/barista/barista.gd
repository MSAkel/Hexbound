extends ChefCard

## Beverages on this course may fire a second time.
const REPEAT_ODDS := 5


func on_card_activated(ctx: ChefContext, tile: Hex, card: TileCard) -> void:
	# A repeat this chef caused does not roll again.
	if ctx.is_chef_caused_activation() or not ctx.is_on_course(tile):
		return
	if not card.has_ingredient_tag(TileCard.TAG_BEVERAGE):
		return
	if ctx.rng("beverage").randi_range(1, REPEAT_ODDS) != 1:
		return
	var again: Array[TileCard] = [card]
	ctx.queue_triggers(again)
