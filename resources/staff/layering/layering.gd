extends StaffCard

## Raises the Garnish stack cap by one for cards on this station.
const EXTRA_STACKS := 1


func bonus_max_garnish_stacks(ctx: StaffContext, tile: Hex, _card: TileCard) -> int:
	return EXTRA_STACKS if ctx.is_on_station(tile) else 0


func on_card_garnished(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	# Only light up when a stack lands that the base cap would have refused.
	if ctx.is_on_station(tile) and card.garnish_stacks > TileCard.MAX_GARNISH_STACKS:
		ctx.pulse(tile)
