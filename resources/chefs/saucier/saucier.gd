extends ChefCard

## Doubled Ingredients on this station gain one more Double, once each per Hour.
## Checked when the station starts and whenever an Ingredient here gains a Double.


func on_station_started(ctx: ChefContext) -> void:
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.is_empowered:
			_add_double(ctx, ctx.map.get_hex_for_tile_card(card), card)


func on_card_doubled(ctx: ChefContext, tile: Hex, card: TileCard) -> void:
	if not ctx.is_on_station(tile) or card.type != TileCard.TileCardType.INGREDIENT:
		return
	_add_double(ctx, tile, card)


func _add_double(ctx: ChefContext, tile: Hex, card: TileCard) -> void:
	var boosted: Array = ctx.hour_state.get_or_add("boosted", [])
	if card in boosted:
		return
	# Mark first. The extra Double re-enters on_card_doubled for this same card.
	boosted.append(card)
	if card._empower():
		ctx.pulse(tile)
