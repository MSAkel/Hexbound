extends StaffCard

## The first Meal served on this station each Hour has a 1 in 3 chance to pay Gold.
const GOLD_ON_HIT := 2
const ONE_IN := 3


func on_meal_served(ctx: StaffContext, tile: Hex, _meal: TileCard) -> void:
	if not ctx.is_on_station(tile) or ctx.hour_state.get("paid", false):
		return
	ctx.hour_state["paid"] = true
	if ctx.rng("daily_special").randi_range(0, ONE_IN - 1) == 0:
		ctx.add_gold(GOLD_ON_HIT)
