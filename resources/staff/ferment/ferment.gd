extends StaffCard

## The growth lives on the card, so it stays if the Fruit moves to another row.
const FLAVOUR_PER_TRIGGER := 2.0
const GROWTH_KEY := "ferment"


func flat_flavour_for(ctx: StaffContext, _tile: Hex, card: TileCard) -> int:
	# Only the original pays, so a copy does not count the same growth twice.
	if ctx.owner != ctx.effect:
		return 0
	return roundi(float(card.perk_growth.get(GROWTH_KEY, 0.0)))


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if ctx.owner != ctx.effect or not ctx.is_on_station(tile):
		return
	if card.type != TileCard.TileCardType.INGREDIENT or not card.has_ingredient_tag(TileCard.TAG_FRUIT):
		return
	card.perk_growth[GROWTH_KEY] = float(card.perk_growth.get(GROWTH_KEY, 0.0)) + FLAVOUR_PER_TRIGGER
