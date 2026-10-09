extends ChefCard

## Rewards a course that holds no Kitchenware at all.
const FLAVOUR_BONUS := 100


func on_course_started(ctx: ChefContext) -> void:
	if not ctx.course_cards(TileCard.TileCardType.KITCHENWARE).is_empty():
		return
	ctx.add_flavour(FLAVOUR_BONUS)
