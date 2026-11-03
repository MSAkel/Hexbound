extends StaffCard

## Early-game boost that switches off after Day 3.
const MULT_PER_MEAL := 3.0
const LAST_DAY := 3


func on_meal_served(ctx: StaffContext, tile: Hex, _meal: TileCard) -> void:
	if ctx.is_on_station(tile) and GameManager.current_round <= LAST_DAY:
		ctx.add_mult(MULT_PER_MEAL)
