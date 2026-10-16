extends StaffCard

## Mult for each Seasoning fire earlier in the Hour. Retriggers count.
const MULT_PER_SEASONING := 0.5


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(MULT_PER_SEASONING * StaffManager.get_seasoning_fires_this_hour())
