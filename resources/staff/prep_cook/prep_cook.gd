extends StaffCard

## Mult for each Ingredient seated on this station.
const MULT_PER_INGREDIENT := 2.0


func on_station_started(ctx: StaffContext) -> void:
	var ingredients := ctx.station_cards(TileCard.TileCardType.INGREDIENT)
	ctx.add_mult(MULT_PER_INGREDIENT * ingredients.size())
