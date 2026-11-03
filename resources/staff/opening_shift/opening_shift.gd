extends StaffCard

const MULT_FIRST_HOUR := 3.0


func on_station_started(ctx: StaffContext) -> void:
	if GameManager.get_turn_number() == 1:
		ctx.add_mult(MULT_FIRST_HOUR)
