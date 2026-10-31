extends MealCard

## Needs a Fruit, a Sweet and a Blender. +3 Mult, plus +1 Mult for each different meal category
## being served on the board, its own Dessert included.

const MULT_PER_CATEGORY := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount() + MULT_PER_CATEGORY * float(_served_category_count(tile))}


func _served_category_count(tile: Hex) -> int:
	var categories := {}
	for meal: MealCard in _serving_meals_on_board(tile):
		if meal.meal_category != MealCategory.NONE:
			categories[meal.meal_category] = true
	return categories.size()
