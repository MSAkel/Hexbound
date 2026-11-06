extends StaffCard

## Grows for the rest of the run with every Condiment used, wherever it lands.
const MULT_PER_CONDIMENT := 0.5


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_condiment_used(ctx: StaffContext, _condiment: Condiment) -> void:
	ctx.grow("mult", MULT_PER_CONDIMENT)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
