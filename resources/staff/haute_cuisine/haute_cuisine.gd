extends StaffCard

## Makes its own stars, so it works without Star Anise or duplicates.
const MULT_PER_EXTRA_STAR := 1.0


func on_station_started(ctx: StaffContext) -> void:
	var extra_stars := 0
	for card: TileCard in ctx.station_cards():
		extra_stars += maxi(card.star_level - 1, 0)
	ctx.add_mult(MULT_PER_EXTRA_STAR * extra_stars)


func on_day_ended(ctx: StaffContext) -> void:
	for card: TileCard in ctx.station_cards():
		if card.star_level >= TileCard.MAX_STAR_LEVEL:
			continue
		card.star_level += 1
		var tile := ctx.map.get_hex_for_tile_card(card)
		if tile != null:
			tile.refresh_tile_card_visual_state()
		ctx.pulse(tile)
		return
