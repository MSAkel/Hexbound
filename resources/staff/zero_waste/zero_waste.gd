extends StaffCard

## Pays gold each time a card on this station is destroyed.
const GOLD_PER_DESTROY := 2


func on_card_destroyed(ctx: StaffContext, tile: Hex, _card: TileCard) -> void:
	if ctx.is_on_station(tile):
		ctx.add_gold(GOLD_PER_DESTROY)
