extends StaffCard

## Forager doubles these, since they join the card's base before every multiplier.
const FLAVOUR := 6
const FLAVOUR_ON_COLD := 12
const COLD_STATION_ID := "cold_station"


func hook_flags() -> int:
	return HOOK_FLAT_FLAVOUR


func flat_flavour_for(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not ctx.is_on_station(tile):
		return 0
	if not (card.has_ingredient_tag(TileCard.TAG_VEGETABLE) or card.has_ingredient_tag(TileCard.TAG_FRUIT)):
		return 0
	if StationManager.get_station_type_id(ctx.slot) == COLD_STATION_ID:
		return FLAVOUR_ON_COLD
	return FLAVOUR
