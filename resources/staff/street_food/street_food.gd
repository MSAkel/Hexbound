extends StaffCard

## Strong before the row forms a station type, small afterwards.
const FLAVOUR_UNTYPED := 40
const MULT_UNTYPED := 2.0
const MULT_TYPED := 1.0


func on_station_started(ctx: StaffContext) -> void:
	if StationManager.get_station_type(ctx.slot) != null:
		ctx.add_mult(MULT_TYPED)
		return
	ctx.add_flavour(FLAVOUR_UNTYPED)
	ctx.add_mult(MULT_UNTYPED)
