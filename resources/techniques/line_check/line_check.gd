extends StaffCard

## +2 Mult for each Station perk taken across every Station (Chef de Cuisine takes every pick, so it
## pays more there). Perks are only picked while Station levelling is on. Untuned.
const MULT_PER_PICK := 2.0


func on_station_started(ctx: StaffContext) -> void:
	var picks := 0
	var segments := ctx.map.get_segment_count() if ctx.map != null else 0
	for segment in segments:
		picks += StationManager.get_picked_perks(segment).size()
	ctx.add_mult(MULT_PER_PICK * float(picks))
