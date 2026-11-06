extends StaffCard

## Pitmaster partner that grows through the Day.
const MULT_PER_HOUR := 1.0


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if not ctx.is_on_station(tile) or not (meal is MealCard):
		return
	var dish := meal as MealCard
	if not (
		StationManager.meal_counts_as(dish, tile, MealCard.MealCategory.MEAT)
		or StationManager.meal_counts_as(dish, tile, MealCard.MealCategory.POULTRY)
	):
		return
	ctx.add_mult(MULT_PER_HOUR * (StationManager.hour_number() - 1))
