extends StaffCard

## The bonus lands on the station of the next Meal, whichever row that is.
const MULT_FOR_NEXT_MEAL := 3.0
const PENDING_KEY := "ramekins_pending"


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.map == null:
		return
	if int(ctx.owner.run_state.get(PENDING_KEY, 0)) > 0:
		ctx.owner.run_state[PENDING_KEY] = 0
		_pay(ctx, tile)
	if not ctx.is_on_station(tile) or not (meal is MealCard):
		return
	if StationManager.meal_counts_as(meal as MealCard, tile, MealCard.MealCategory.SAUCE):
		ctx.owner.run_state[PENDING_KEY] = 1


func _pay(ctx: StaffContext, tile: Hex) -> void:
	var segment := ctx.map.get_segment_index(tile.coordinates)
	ctx.map.add_turn_additive_mult_for_segment(segment, MULT_FOR_NEXT_MEAL)
	if not GameManager.skip_presentation:
		ctx.map.create_floating_text(
			ctx.map.floating_text_position_for_hex(tile.coordinates),
			CountingNumber.format_additive_mult(MULT_FOR_NEXT_MEAL),
			StaffContext.MULT_COLOR,
			TileCard.ICON_MULT
		)
	ctx.pulse(tile)
