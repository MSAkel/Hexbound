extends StaffCard

## Multiplier growth that rewards finishing Days early.
const MULT_PER_DAY := 0.1
const HOURS_LEFT := 2


func on_station_started(ctx: StaffContext) -> void:
	ctx.multiply_mult(1.0 + run_total("mult_x"))


func on_day_ended(ctx: StaffContext) -> void:
	if GameManager.get_skipped_turns() >= HOURS_LEFT:
		ctx.grow("mult_x", MULT_PER_DAY)


func get_progress_text() -> String:
	return "x%.1f {mult}" % (1.0 + run_total("mult_x"))
