extends StaffCard

## The growth lives on the card, so it stays if the Vegetable moves to another row.
const FLAVOUR_PER_DAY := 5.0
const GROWTH_KEY := "pickling"


func hook_flags() -> int:
	return HOOK_FLAT_FLAVOUR


func flat_flavour_for(ctx: StaffContext, _tile: Hex, card: TileCard) -> int:
	# Only the original pays, so a copy does not count the same growth twice.
	if ctx.owner != ctx.effect:
		return 0
	return roundi(float(card.perk_growth.get(GROWTH_KEY, 0.0)))


func on_day_ended(ctx: StaffContext) -> void:
	if ctx.owner != ctx.effect:
		return
	var last: TileCard = null
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.has_ingredient_tag(TileCard.TAG_VEGETABLE):
			last = card
	if last == null:
		return
	last.perk_growth[GROWTH_KEY] = float(last.perk_growth.get(GROWTH_KEY, 0.0)) + FLAVOUR_PER_DAY
	ctx.pulse(ctx.map.get_hex_for_tile_card(last))
