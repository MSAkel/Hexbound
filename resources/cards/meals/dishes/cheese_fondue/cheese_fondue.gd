extends MealCard

## Needs Cheese and Milk. +5 Mult, then x0.05 Mult on top of x1 for every trigger on its station this Hour.

const XMULT_PER_TRIGGER := 0.05


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var triggers := 0
	if tile != null and tile.map != null:
		triggers = _get_segment_trigger_count_this_turn(tile)
	return {
		"additive_mult": _get_production_amount(),
		"multiplicative_mult": 1.0 + XMULT_PER_TRIGGER * float(triggers),
	}
