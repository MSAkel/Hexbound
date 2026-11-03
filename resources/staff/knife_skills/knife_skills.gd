extends StaffCard

## Counts every Kitchenware trigger, repeats and retriggers included.
const MULT_PER_TRIGGER := 1.0


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if ctx.is_on_station(tile) and card.type == TileCard.TileCardType.KITCHENWARE:
		ctx.add_mult(MULT_PER_TRIGGER)
