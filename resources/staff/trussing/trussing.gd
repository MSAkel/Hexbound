extends StaffCard

const SCALE := 1.5
const SCALE_WITH_VEGETABLE := 2.0


func output_scale_for(ctx: StaffContext, tile: Hex, card: TileCard) -> float:
	if not ctx.is_on_station(tile) or not (card is MealCard):
		return 1.0
	if not StationManager.meal_counts_as(card as MealCard, tile, MealCard.MealCategory.POULTRY):
		return 1.0
	for other: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if other.has_ingredient_tag(TileCard.TAG_VEGETABLE):
			return SCALE_WITH_VEGETABLE
	return SCALE
