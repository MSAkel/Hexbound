extends StaffCard

## Once per Day, on this station's first Hour.
const STACKS := 2
const DAY_KEY := "decanting_day"


func on_station_started(ctx: StaffContext) -> void:
	if int(ctx.owner.run_state.get(DAY_KEY, 0)) == GameManager.current_round:
		return
	ctx.owner.run_state[DAY_KEY] = GameManager.current_round
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.MEAL):
		if not card.has_ingredient_tag(TileCard.TAG_BEVERAGE):
			continue
		var added := false
		for _i in STACKS:
			if card.add_garnish():
				added = true
		if added:
			ctx.pulse(ctx.map.get_hex_for_tile_card(card))
		return
