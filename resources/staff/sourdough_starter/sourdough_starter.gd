extends StaffCard

## Grows for the rest of the run with every Meal served on this station.
const MULT_PER_MEAL := 0.5


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_meal_served(ctx: StaffContext, tile: Hex, _meal: TileCard) -> void:
	if ctx.is_on_station(tile):
		ctx.grow("mult", MULT_PER_MEAL, tile)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
