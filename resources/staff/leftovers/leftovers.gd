extends StaffCard

## Turns an unready Meal into growth instead of nothing. No card is gained.
const MULT_PER_FAIL := 1.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_meal_failed(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if not ctx.is_on_station(tile) or bool(ctx.hour_state.get("fed", false)):
		return
	ctx.hour_state["fed"] = true
	meal.add_garnish()
	ctx.grow("mult", MULT_PER_FAIL, tile)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
