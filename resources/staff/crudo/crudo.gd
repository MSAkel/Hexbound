extends StaffCard

## Rewards a station that holds no Kitchenware at all.
const FLAVOUR_BONUS := 100


func on_station_started(ctx: StaffContext) -> void:
	if not ctx.station_cards(TileCard.TileCardType.KITCHENWARE).is_empty():
		return
	ctx.add_flavour(FLAVOUR_BONUS)
