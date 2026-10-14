extends StaffCard

## Kitchenware Garnishes anywhere on the pass may land twice.
const TWICE_ODDS := 4


func extra_garnish_applications(
	ctx: StaffContext,
	_source_tile: Hex,
	_source_card: TileCard,
	target: TileCard
) -> int:
	if ctx.rng("garnish").randi_range(1, TWICE_ODDS) != 1:
		return 0
	ctx.pulse(ctx.map.get_hex_for_tile_card(target) if ctx.map != null else null)
	return 1
