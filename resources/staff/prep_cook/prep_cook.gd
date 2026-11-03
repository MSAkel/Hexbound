extends StaffCard

## Early-game Flavour that fades once the station levels up.
const FLAVOUR_PER_INGREDIENT := 15
const LAST_LEVEL := 2


func on_station_started(ctx: StaffContext) -> void:
	if StationManager.get_level(ctx.slot) > LAST_LEVEL:
		return
	var ingredients := ctx.station_cards(TileCard.TileCardType.INGREDIENT)
	ctx.add_flavour(FLAVOUR_PER_INGREDIENT * ingredients.size())
