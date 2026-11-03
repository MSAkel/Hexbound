extends StaffCard

## Works from any seat. Ties go to the Meal that reached the count first.
const SCALE := 1.5
const COUNTS_KEY := "served_counts"
const TOP_KEY := "top_meal"


func output_scale_for(_ctx: StaffContext, _tile: Hex, card: TileCard) -> float:
	if card.type != TileCard.TileCardType.MEAL:
		return 1.0
	return SCALE if card.id == str(run_state.get(TOP_KEY, "")) else 1.0


func on_meal_served(ctx: StaffContext, tile: Hex, meal: TileCard) -> void:
	if ctx.owner != ctx.effect:
		return
	var counts: Dictionary = run_state.get(COUNTS_KEY, {})
	var count := int(counts.get(meal.id, 0)) + 1
	counts[meal.id] = count
	run_state[COUNTS_KEY] = counts
	var top := str(run_state.get(TOP_KEY, ""))
	if top != meal.id and count > int(counts.get(top, 0)):
		run_state[TOP_KEY] = meal.id
		ctx.pulse(tile)


func get_progress_text() -> String:
	var top := str(run_state.get(TOP_KEY, ""))
	if top.is_empty():
		return ""
	return top.replace("_", " ").capitalize()
