extends StaffCard

## Grilling and Roasting setups both pair Meat with Seasoning.
const FLAVOUR_PER_SEASONING := 3


func flat_flavour_for(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not ctx.is_on_station(tile) or not card.has_ingredient_tag(TileCard.TAG_MEAT):
		return 0
	var seasonings := 0
	for other: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if other.has_ingredient_tag(TileCard.TAG_SEASONING):
			seasonings += 1
	return FLAVOUR_PER_SEASONING * seasonings
