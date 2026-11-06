extends StaffCard

## Pastry Chef partner: every Sweet Garnish on this station grows it for the rest of the run.
const MULT_PER_GARNISH := 1.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_card_garnished(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if ctx.is_on_station(tile) and card.has_ingredient_tag(TileCard.TAG_SWEET):
		ctx.grow("mult", MULT_PER_GARNISH, tile)


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
