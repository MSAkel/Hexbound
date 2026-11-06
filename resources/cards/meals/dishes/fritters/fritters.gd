extends MealCard

## Needs a Vegetable. +40 Flavour, plus +10 Flavour for each extra trigger a Deep Fryer on its
## station gives this Hour, plus +10 Flavour for each different kind of Ingredient on its station.

const FLAVOUR_PER_KIND := 10.0
const FLAVOUR_PER_FRY := 10.0


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var flavour := _get_production_amount() + FLAVOUR_PER_FRY * float(_deep_fryer_triggers(tile, preview))
	return {"flavour": int(round(flavour + FLAVOUR_PER_KIND * float(_station_kinds(tile).size())))}


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _station_cards(tile):
		for tag: StringName in card.get_kind_tags():
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
