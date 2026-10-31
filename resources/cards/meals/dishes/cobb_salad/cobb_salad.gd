extends MealCard

## Needs Chicken, Avocado and Lettuce. Starts at x1 Mult and gains x0.25 for each different kind
## of Ingredient on its station.

const XMULT_PER_KIND := 0.25


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"multiplicative_mult": 1.0 + XMULT_PER_KIND * float(_station_kinds(tile).size())}


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _station_cards(tile):
		for tag: StringName in card.ingredient_tags:
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
