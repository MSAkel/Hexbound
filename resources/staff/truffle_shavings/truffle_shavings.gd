extends StaffCard

## Multiplies Mult by banked gold, a step per GOLD_STEP held.
const GOLD_STEP := 5
const MULT_PER_STEP := 0.1


func on_station_started(ctx: StaffContext) -> void:
	var steps := floori(maxi(0, EconomyManager.amount) / float(GOLD_STEP))
	ctx.multiply_mult(1.0 + MULT_PER_STEP * steps)
