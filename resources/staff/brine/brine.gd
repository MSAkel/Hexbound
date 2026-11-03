extends StaffCard

## One Seafood per Hour, so it adds to Catch of the Day instead of replacing it.


func on_station_started(ctx: StaffContext) -> void:
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if not card.has_ingredient_tag(TileCard.TAG_SEAFOOD):
			continue
		if card.add_garnish():
			ctx.pulse(ctx.map.get_hex_for_tile_card(card))
		return
