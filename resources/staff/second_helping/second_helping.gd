extends StaffCard

## Fires the first Meal served on this station again, once per Hour.


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.is_staff_caused_activation() or not ctx.is_on_station(tile):
		return
	if ctx.hour_state.get("served", false):
		return
	ctx.hour_state["served"] = true
	var again: Array[TileCard] = [meal]
	ctx.queue_triggers(again)
