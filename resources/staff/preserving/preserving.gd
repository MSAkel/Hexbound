extends StaffCard

## Garnished cards on this station carry one stack into the next Hour.
const KEPT_STACKS := 1


func garnish_kept_after_hour(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not ctx.is_on_station(tile) or not card.is_garnished:
		return 0
	ctx.pulse(tile)
	return KEPT_STACKS
