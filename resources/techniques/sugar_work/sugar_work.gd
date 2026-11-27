extends StaffCard

## Pays after the station is done, so this Hour's Desserts count.
const MULT_PER_SWEET := 1.0
## Flat bonus, paid once however many Desserts the station served.
const DESSERT_MULT := 2.0


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.is_on_station(tile) and _counts_as(meal, tile, MealCard.MealCategory.DESSERT):
		ctx.hour_state["dessert"] = true


func on_station_finished(ctx: StaffContext) -> void:
	var sweets := 0
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.has_ingredient_tag(TileCard.TAG_SWEET):
			sweets += 1
	var mult: float = MULT_PER_SWEET * sweets
	if bool(ctx.hour_state.get("dessert", false)):
		mult += DESSERT_MULT
	ctx.add_mult(mult)


func _counts_as(meal: TileCard, tile: Hex, category: int) -> bool:
	return meal is MealCard and StationManager.meal_counts_as(meal as MealCard, tile, category)
