extends MealCard

## Needs Potato and Butter. +10 Mult, plus +5 Mult for each different kind of Ingredient on its station.

const MULT_PER_KIND := 5.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_KIND * float(_station_kinds(tile).size())}


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _station_cards(tile):
		for tag: StringName in card.ingredient_tags:
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
