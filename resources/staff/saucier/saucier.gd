extends StaffCard

## Garnished Ingredients on this station gain one more Garnish, once each per Hour.
## Checked when the station starts and whenever an Ingredient here gains a Garnish.


func on_station_started(ctx: StaffContext) -> void:
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.is_garnished:
			_add_garnish(ctx, ctx.map.get_hex_for_tile_card(card), card)


func on_card_garnished(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if not ctx.is_on_station(tile) or card.type != TileCard.TileCardType.INGREDIENT:
		return
	_add_garnish(ctx, tile, card)


func _add_garnish(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	var boosted: Array = ctx.hour_state.get_or_add("boosted", [])
	if card in boosted:
		return
	# Mark first. The extra Garnish re-enters on_card_garnished for this same card.
	boosted.append(card)
	if card.add_garnish():
		ctx.pulse(tile)
