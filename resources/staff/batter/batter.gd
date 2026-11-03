extends StaffCard

## Fry Station partner: the Deep Fryer's best targets, and the Meals Fry boosts.
const FLAVOUR := 10
const MULT_PER_SIDE := 2.0
const BATTER_IDS: Array[String] = ["potato", "chicken"]


func flat_flavour_for(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not ctx.is_on_station(tile):
		return 0
	if card.id in BATTER_IDS or StationManager.counts_as_potato(tile, card):
		return FLAVOUR
	return 0


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if not ctx.is_on_station(tile) or not (meal is MealCard):
		return
	if StationManager.meal_counts_as(meal as MealCard, tile, MealCard.MealCategory.SIDE):
		ctx.add_mult(MULT_PER_SIDE)
