extends StaffCard

## Bar Station partner: its setup asks for different Fruits.
const MULT_PER_FRUIT := 2.0
const FRUITS_FOR_SCALE := 3
const BEVERAGE_SCALE := 1.5


func hook_flags() -> int:
	return HOOK_OUTPUT_SCALE


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_mult(MULT_PER_FRUIT * _different_fruits(ctx))


func output_scale_for(ctx: StaffContext, tile: Hex, card: TileCard) -> float:
	if not ctx.is_on_station(tile) or card.type != TileCard.TileCardType.MEAL:
		return 1.0
	if not card.has_ingredient_tag(TileCard.TAG_BEVERAGE):
		return 1.0
	return BEVERAGE_SCALE if _different_fruits(ctx) >= FRUITS_FOR_SCALE else 1.0


func _different_fruits(ctx: StaffContext) -> int:
	var ids: Array[String] = []
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		if card.has_ingredient_tag(TileCard.TAG_FRUIT) and card.id not in ids:
			ids.append(card.id)
	return ids.size()
