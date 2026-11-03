extends StaffCard

## Counts Sauce & Dip meals served on any station today, so earlier rows feed later ones.
const FLAVOUR_PER_SAUCE := 4
const DAY_KEY := "emulsion_day"
const COUNT_KEY := "emulsion_sauces"


func flat_flavour_for(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not ctx.is_on_station(tile):
		return 0
	if not (card.has_ingredient_tag(TileCard.TAG_DAIRY) or card.has_ingredient_tag(TileCard.TAG_SEASONING)):
		return 0
	return FLAVOUR_PER_SAUCE * _sauces_today()


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.owner != ctx.effect or not (meal is MealCard):
		return
	if not StationManager.meal_counts_as(meal as MealCard, tile, MealCard.MealCategory.SAUCE):
		return
	if int(run_state.get(DAY_KEY, 0)) != GameManager.current_round:
		run_state[DAY_KEY] = GameManager.current_round
		run_state[COUNT_KEY] = 0
	run_state[COUNT_KEY] = int(run_state.get(COUNT_KEY, 0)) + 1


func _sauces_today() -> int:
	if int(run_state.get(DAY_KEY, 0)) != GameManager.current_round:
		return 0
	return int(run_state.get(COUNT_KEY, 0))
