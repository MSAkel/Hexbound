extends StaffCard

## Pays after the station is done, so this Hour's Desserts count.
const MULT_PER_SWEET := 1.0
const MULT_PER_SWEET_AFTER_DESSERT := 3.0


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.is_on_station(tile) and _counts_as(meal, tile, MealCard.MealCategory.DESSERT):
		ctx.hour_state["dessert"] = true


func on_station_finished(ctx: StaffContext) -> void:
	var sweets := 0
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.has_ingredient_tag(TileCard.TAG_SWEET):
			sweets += 1
	var per_sweet: float = MULT_PER_SWEET
	if bool(ctx.hour_state.get("dessert", false)):
		per_sweet = MULT_PER_SWEET_AFTER_DESSERT
	ctx.add_mult(per_sweet * sweets)


func _counts_as(meal: TileCard, tile: Hex, category: int) -> bool:
	return meal is MealCard and StationManager.meal_counts_as(meal as MealCard, tile, category)
