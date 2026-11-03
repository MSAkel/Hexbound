extends StaffCard

## Fish Station partner: its setup already pairs Seafood with Fruit.
const FLAVOUR_PER_FRUIT := 15


func flat_flavour_for(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not ctx.is_on_station(tile) or not card.has_ingredient_tag(TileCard.TAG_SEAFOOD):
		return 0
	var fruits := 0
	for other: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if other.has_ingredient_tag(TileCard.TAG_FRUIT):
			fruits += 1
	return FLAVOUR_PER_FRUIT * fruits
