extends StaffCard

## Garnishes every Seafood on this station before the station fires.


func on_station_started(ctx: StaffContext) -> void:
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.has_ingredient_tag(TileCard.TAG_SEAFOOD) and card.add_garnish():
			ctx.pulse(ctx.map.get_hex_for_tile_card(card))
