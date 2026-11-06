extends StaffCard

## Pays after the station is done, once its Meals have been served.
const MULT_PER_MEAL := 1.0
const FULL_PASS_SCALE := 2.0


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.is_on_station(tile):
		var served: Dictionary = ctx.hour_state.get_or_add("served", {})
		served[meal] = true


func on_station_finished(ctx: StaffContext) -> void:
	var served: Dictionary = ctx.hour_state.get("served", {})
	var mult := MULT_PER_MEAL * served.size()
	if served.size() >= 2:
		mult *= FULL_PASS_SCALE
	ctx.add_mult(mult)
