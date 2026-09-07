extends DishCard

## If the 2 previous spots are seasonings, write x3 course Mult.
## That x is multiplicative_mult, not additive +Mult.

const RECIPE_XMULT := 3.0


func _plated_multiplicative_mult_from_recipe(_recipe: Array[TileCard]) -> float:
	return RECIPE_XMULT
