extends StaffCard

## Grows with Meal variety, not Meal count (station levels already count Meals).
const MULT_PER_NEW_MEAL := 1.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	# A copy pays the total out but keeps no list of its own.
	if ctx.owner != ctx.effect or not ctx.is_on_station(tile):
		return
	var seen: Array = run_state.get("seen", [])
	if meal.id in seen:
		return
	seen.append(meal.id)
	run_state["seen"] = seen
	ctx.grow("mult", MULT_PER_NEW_MEAL, tile)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
