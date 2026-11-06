extends StaffCard

## A Destroy source for Deglaze and Zero Waste. Never breaks the station's setup.
const MULT_PER_DESTROY := 2.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(run_total("mult"))


func on_day_ended(ctx: StaffContext) -> void:
	# A copy pays the total out but destroys nothing.
	if ctx.owner != ctx.effect or ctx.map == null:
		return
	var target := _target(ctx)
	if target == null:
		return
	var tile := ctx.map.get_hex_for_tile_card(target)
	if CondimentBoardEffects.destroy_placed_at(tile, target):
		ctx.grow("mult", MULT_PER_DESTROY, tile)


func _target(ctx: StaffContext) -> TileCard:
	var station_type := StationManager.get_station_type(ctx.slot)
	var all_cards := ctx.station_cards()
	var best: TileCard = null
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if best != null and card.base_production_amount >= best.base_production_amount:
			continue
		if station_type != null:
			var rest: Array[TileCard] = []
			rest.assign(all_cards)
			rest.erase(card)
			if not station_type.is_satisfied_by(rest):
				continue
		best = card
	return best


func get_progress_text() -> String:
	return "%s {mult}" % format_total(run_total("mult"))
