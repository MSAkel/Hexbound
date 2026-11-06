extends StaffCard

## A Garnish on a card on this station keeps boosting for one more Hour before it is used up.
const EXTRA_HOURS := 1


func extra_garnish_hours(ctx: StaffContext, tile: Hex, _card: TileCard) -> int:
	if not ctx.is_on_station(tile):
		return 0
	ctx.pulse(tile)
	return EXTRA_HOURS
