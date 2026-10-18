extends StaffCard

## Rewards merged and starred cards on this station.
const MULT_PER_EXTRA_STAR := 1.0


func on_station_started(ctx: StaffContext) -> void:
	var extra_stars := 0
	for card: TileCard in ctx.station_cards():
		extra_stars += maxi(card.star_level - 1, 0)
	ctx.add_mult(MULT_PER_EXTRA_STAR * extra_stars)
