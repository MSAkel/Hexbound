extends StaffCard

const SCALE_PER_VEGETABLE := 0.25


func hook_flags() -> int:
	return HOOK_OUTPUT_SCALE


func output_scale_for(ctx: StaffContext, tile: Hex, card: TileCard) -> float:
	if not ctx.is_on_station(tile) or not (card is MealCard):
		return 1.0
	if not StationManager.meal_counts_as(card as MealCard, tile, MealCard.MealCategory.SALAD):
		return 1.0
	var ids: Array[String] = []
	for other: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if other.has_ingredient_tag(TileCard.TAG_VEGETABLE) and other.id not in ids:
			ids.append(other.id)
	return 1.0 + SCALE_PER_VEGETABLE * ids.size()
