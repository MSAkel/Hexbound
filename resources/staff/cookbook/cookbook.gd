extends StaffCard

## Multiplier growth with no cap, fed by Meal variety every Day.
const MULT_PER_MEAL := 0.02


func on_station_started(ctx: StaffContext) -> void:
	ctx.multiply_mult(1.0 + run_total("mult_x"))


func on_meal_served(ctx: StaffContext, _tile: Hex, meal: TileCard) -> void:
	if ctx.owner == ctx.effect:
		DayMealLog.record(run_state, meal)


func on_day_ended(ctx: StaffContext) -> void:
	if ctx.owner != ctx.effect:
		return
	ctx.grow("mult_x", MULT_PER_MEAL * DayMealLog.count(run_state))
	DayMealLog.clear(run_state)


func get_progress_text() -> String:
	return "x%.2f {mult}" % (1.0 + run_total("mult_x"))
