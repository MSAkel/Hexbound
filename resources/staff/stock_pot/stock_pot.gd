extends StaffCard

## Counts Meals served on any station. Grows for the rest of the run.
const FLAVOUR_PER_MEAL := 5.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_flavour(roundi(run_total("flavour")))


func on_meal_served(ctx: StaffContext, _tile: Hex, meal: TileCard) -> void:
	if ctx.owner == ctx.effect:
		DayMealLog.record(run_state, meal)


func on_day_ended(ctx: StaffContext) -> void:
	if ctx.owner != ctx.effect:
		return
	ctx.grow("flavour", FLAVOUR_PER_MEAL * DayMealLog.count(run_state))
	DayMealLog.clear(run_state)


func get_progress_text() -> String:
	return "%s {flavour}" % format_total(run_total("flavour"))
