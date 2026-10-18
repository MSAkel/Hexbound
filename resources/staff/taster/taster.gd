extends StaffCard

## Rewards a mixed station. Kinds are the recipe tags (Vegetable, Fruit, Meat...).
const FLAVOUR_PER_KIND := 15


func on_station_started(ctx: StaffContext) -> void:
	var kinds := {}
	for card: TileCard in ctx.station_cards(TileCard.TileCardType.INGREDIENT):
		for tag: StringName in card.ingredient_tags:
			if tag in TileCard.RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	ctx.add_flavour(FLAVOUR_PER_KIND * kinds.size())
