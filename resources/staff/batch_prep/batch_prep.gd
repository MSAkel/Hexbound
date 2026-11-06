extends StaffCard

## Rewards doubled-up kinds, which most station setups ask for.
const MULT_PER_INGREDIENT := 2.0


func on_station_started(ctx: StaffContext) -> void:
	var ingredients := ctx.station_cards(TileCard.TileCardType.INGREDIENT)
	var counts: Dictionary = {}
	for card: TileCard in ingredients:
		for tag: StringName in _kinds(card):
			counts[tag] = int(counts.get(tag, 0)) + 1
	var matched := 0
	for card: TileCard in ingredients:
		for tag: StringName in _kinds(card):
			if int(counts.get(tag, 0)) > 1:
				matched += 1
				break
	ctx.add_mult(MULT_PER_INGREDIENT * matched)


func _kinds(card: TileCard) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for tag: StringName in card.get_kind_tags():
		if tag in TileCard.RECIPE_INGREDIENT_TAGS and tag not in kinds:
			kinds.append(tag)
	return kinds
