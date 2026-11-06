extends StaffCard

## Multiplies the running Mult once this station has finished firing, so it is strongest last in line.
const MULT_PER_TRIGGER := 0.1


func on_station_finished(ctx: StaffContext) -> void:
	if ctx.map == null:
		return
	var triggers := ctx.map.get_segment_turn_trigger_count(ctx.slot)
	ctx.multiply_mult(1.0 + MULT_PER_TRIGGER * triggers)
