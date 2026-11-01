extends StaffCard

## A Garnish on a card on this station boosts one more trigger before it is used up.
const EXTRA_TRIGGERS := 1


func extra_garnish_triggers(ctx: StaffContext, tile: Hex, _card: TileCard) -> int:
	if not ctx.is_on_station(tile):
		return 0
	ctx.pulse(tile)
	return EXTRA_TRIGGERS
