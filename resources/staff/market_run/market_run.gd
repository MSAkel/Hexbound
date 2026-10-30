extends StaffCard

## Grows for the rest of the run with gold spent, a step per GOLD_STEP.
const GOLD_STEP := 5
const MULT_PER_STEP := 0.5


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(_mult())


func on_gold_spent(ctx: StaffContext, amount: int) -> void:
	ctx.grow("spent", amount)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(_mult())


func _mult() -> float:
	return MULT_PER_STEP * floori(run_total("spent") / GOLD_STEP)
