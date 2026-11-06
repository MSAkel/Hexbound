extends StaffCard

## Chef de Cuisine takes every pick, so this pays up to four times there.
const MULT_PER_PICK := 2.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(MULT_PER_PICK * StationManager.get_picked_perks(ctx.slot).size())
