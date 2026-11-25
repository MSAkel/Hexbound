extends MealCard

## Needs Lettuce, a Meat and a Fruit (the real salad's chicken or bacon and avocado). +40 Flavour,
## +10 Flavour for each different kind of Ingredient on its station. No Mult. Untuned.

const FLAVOUR_PER_KIND := 10


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {
		"flavour": int(round(_get_production_amount())) + FLAVOUR_PER_KIND * _station_kinds(tile).size(),
	}


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _station_cards(tile):
		for tag: StringName in card.get_kind_tags():
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
