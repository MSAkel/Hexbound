extends MealCard

## Needs Cream, Sugar and a Kitchen Torch. +20 Mult.


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount()}
