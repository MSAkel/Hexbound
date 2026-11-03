extends StaffCard

## The growth lives on the card and pays each time that Kitchenware triggers, on whichever row.
const MULT_PER_DAY := 1.0
const GROWTH_KEY := "seasoned_pan"


func on_day_ended(ctx: StaffContext) -> void:
	if ctx.owner != ctx.effect:
		return
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.KITCHENWARE):
		card.perk_growth[GROWTH_KEY] = float(card.perk_growth.get(GROWTH_KEY, 0.0)) + MULT_PER_DAY
		ctx.pulse(ctx.map.get_hex_for_tile_card(card))


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	# Only the original pays, so a copy does not count the same growth twice.
	if ctx.owner != ctx.effect or card.type != TileCard.TileCardType.KITCHENWARE:
		return
	_pay_mult_at(ctx, tile, float(card.perk_growth.get(GROWTH_KEY, 0.0)))


## Adds Mult to the station of tile, with the usual float, since the card may sit on another row.
func _pay_mult_at(ctx: StaffContext, tile: Hex, amount: float) -> void:
	if ctx.map == null or tile == null or is_zero_approx(amount):
		return
	ctx.map.add_turn_additive_mult_for_segment(ctx.map.get_segment_index(tile.coordinates), amount)
	if not GameManager.skip_presentation:
		ctx.map.create_floating_text(
			ctx.map.floating_text_position_for_hex(tile.coordinates),
			CountingNumber.format_additive_mult(amount),
			StaffContext.MULT_COLOR,
			TileCard.ICON_MULT
		)
	ctx.pulse(tile)
