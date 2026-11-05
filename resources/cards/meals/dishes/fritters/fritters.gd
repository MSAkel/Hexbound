extends MealCard

## Needs a Deep Fryer and a Vegetable. +40 Flavour, plus +10 Flavour for each different kind of
## Ingredient on its station.

const FLAVOUR_PER_KIND := 10.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"flavour": int(round(_get_production_amount() + FLAVOUR_PER_KIND * float(_station_kinds(tile).size())))}


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _station_cards(tile):
		for tag: StringName in card.ingredient_tags:
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
