extends MealCard

## Plates vegetable Flavour from the prefix, then applies local ×1.5.
## Recipe bag is authored on the resource. 2 Vegetables and 1 Kitchenware.

const LOCAL_MULT := 1.5


func _plated_flavour_from_recipe(recipe: Array[TileCard]) -> int:
	return _scale_flavour(_sum_hour_flavour_for_kind(recipe, TAG_VEGETABLE))


func _preview_plated_flavour(tile: Hex) -> int:
	return _scale_flavour(_sum_expected_flavour_for_kind(tile, TAG_VEGETABLE))


func _scale_flavour(meal_flavour: int) -> int:
	return int(round(float(meal_flavour) * LOCAL_MULT))
