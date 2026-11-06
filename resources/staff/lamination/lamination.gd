extends StaffCard

## Layering and Preserving together, for Sweets only.
const EXTRA_STACKS := 1
const EXTRA_HOURS := 1


func bonus_max_garnish_stacks(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	return EXTRA_STACKS if _is_sweet_here(ctx, tile, card) else 0


func extra_garnish_hours(ctx: StaffContext, tile: Hex, card: TileCard) -> int:
	if not _is_sweet_here(ctx, tile, card):
		return 0
	ctx.pulse(tile)
	return EXTRA_HOURS


func _is_sweet_here(ctx: StaffContext, tile: Hex, card: TileCard) -> bool:
	return ctx.is_on_station(tile) and card.has_ingredient_tag(TileCard.TAG_SWEET)
