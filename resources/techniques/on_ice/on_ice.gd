extends StaffCard

## Counts Seafood still holding their Garnish, so a higher seat sees more of them.
const MULT_PER_SEAFOOD := 2.0


func on_station_started(ctx: StaffContext) -> void:
	var count := 0
	for segment in StaffManager.SLOT_COUNT:
		for card: TileCard in StationManager.station_cards(segment):
			if card.type != TileCard.TileCardType.INGREDIENT or not card.is_garnished:
				continue
			if card.has_ingredient_tag(TileCard.TAG_SEAFOOD):
				count += 1
	ctx.add_mult(MULT_PER_SEAFOOD * count)
