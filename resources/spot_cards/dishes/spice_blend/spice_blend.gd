extends DishCard

## If the 2 previous spots are seasonings, x3 those seasonings' Mult.
## That x is local to their additive Mult. It is not course-wide multiplicative_mult.

const RECIPE_XMULT := 3.0


func _plated_additive_mult_from_recipe(recipe: Array[TileCard]) -> float:
	return _seasoning_xmult_bonus(_sum_hour_additive_mult_for_kind(recipe, TAG_SEASONING))


func _preview_plated_additive_mult(tile: Hex) -> float:
	return _seasoning_xmult_bonus(_sum_expected_additive_mult_for_kind(tile, TAG_SEASONING))


## Seasonings already paid their Mult when they fired. Add the leftover so their net is x3.
func _seasoning_xmult_bonus(seasoning_mult: float) -> float:
	return seasoning_mult * (RECIPE_XMULT - 1.0)
