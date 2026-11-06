extends StaffCard

## Grows for the rest of the run each time a card on this station is destroyed.
const MULT_PER_DESTROY := 1.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_card_destroyed(ctx: StaffContext, tile: Hex, _card: TileCard) -> void:
	if ctx.is_on_station(tile):
		ctx.grow("mult", MULT_PER_DESTROY, tile)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
