extends StaffCard

## A steady Garnish source for Basting, Layering and Preserving.


func on_station_started(ctx: StaffContext) -> void:
	var cards := ctx.station_cards()
	if cards.is_empty():
		return
	var first: TileCard = cards[0]
	if first.add_garnish():
		ctx.pulse(ctx.map.get_hex_for_tile_card(first))
