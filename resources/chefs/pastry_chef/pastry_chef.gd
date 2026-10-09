extends ChefCard

## Raises the Double stack cap by one for cards on this course.
const EXTRA_STACKS := 1


func bonus_max_double_stacks(ctx: ChefContext, tile: Hex, _card: TileCard) -> int:
	return EXTRA_STACKS if ctx.is_on_course(tile) else 0


func on_card_doubled(ctx: ChefContext, tile: Hex, card: TileCard) -> void:
	# Only light up when a stack lands that the base cap would have refused.
	if ctx.is_on_course(tile) and card.empower_stacks > TileCard.MAX_EMPOWER_STACKS:
		ctx.pulse(tile)
