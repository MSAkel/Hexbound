extends DishCard

## Locked to the card text. Plates prefix vegetable Flavour and seasoning Mult, each ×1.5.
## That is a local meal pile, not course-wide ×Mult.

const LOCAL_MULT := 1.5


func _plated_flavour_from_recipe(recipe: Array[TileCard]) -> int:
	return _scale_flavour(_sum_hour_flavour_for_kind(recipe, IngredientKind.VEGETABLE))


func _plated_additive_mult_from_recipe(recipe: Array[TileCard]) -> float:
	return _sum_hour_additive_mult_for_kind(recipe, IngredientKind.SEASONING) * LOCAL_MULT


func _preview_plated_flavour(tile: Hex) -> int:
	return _scale_flavour(_sum_expected_flavour_for_kind(tile, IngredientKind.VEGETABLE))


func _preview_plated_additive_mult(tile: Hex) -> float:
	return _sum_expected_additive_mult_for_kind(tile, IngredientKind.SEASONING) * LOCAL_MULT


func _scale_flavour(meal_flavour: int) -> int:
	return int(round(float(meal_flavour) * LOCAL_MULT))
