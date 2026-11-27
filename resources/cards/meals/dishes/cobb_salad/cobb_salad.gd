extends MealCard

## Needs Lettuce, a Meat and a Fruit (the real salad's chicken or bacon and avocado). +40 Flavour and
## +2 Mult, +10 Flavour and +1 Mult for each different kind of Ingredient on its station. Untuned.

const BASE_FLAVOUR := 40
const FLAVOUR_PER_KIND := 10
const MULT_PER_KIND := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var kind_count := _station_kinds(tile).size()
	return {
		"flavour": BASE_FLAVOUR + FLAVOUR_PER_KIND * kind_count,
		"additive_mult": _get_production_amount() + MULT_PER_KIND * float(kind_count),
	}


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _station_cards(tile):
		for tag: StringName in card.get_kind_tags():
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
