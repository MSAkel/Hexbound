extends StaffCard

## Multiplier growth with no cap. A fresh seat starts from zero.
const SCALE_PER_DAY := 0.1


func hook_flags() -> int:
	return HOOK_OUTPUT_SCALE


func output_scale_for(ctx: StaffContext, tile: Hex, card: TileCard) -> float:
	if not ctx.is_on_station(tile) or card.type != TileCard.TileCardType.INGREDIENT:
		return 1.0
	if not card.has_ingredient_tag(TileCard.TAG_MEAT):
		return 1.0
	return 1.0 + SCALE_PER_DAY * run_total("days")


func on_day_ended(ctx: StaffContext) -> void:
	ctx.grow("days", 1.0)


func get_progress_text() -> String:
	return "x%.1f" % (1.0 + SCALE_PER_DAY * run_total("days"))
