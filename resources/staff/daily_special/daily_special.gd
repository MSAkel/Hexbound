extends StaffCard

## Pays gold for the first Meal served on this station, once per Hour.
const GOLD_PER_HOUR := 2


func on_meal_served(ctx: StaffContext, tile: Hex, _meal: TileCard) -> void:
	if not ctx.is_on_station(tile) or ctx.hour_state.get("paid", false):
		return
	ctx.hour_state["paid"] = true
	ctx.add_gold(GOLD_PER_HOUR)
