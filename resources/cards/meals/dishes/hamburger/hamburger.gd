extends MealCard

## +4 Mult, then x0.1 Mult on top of x1 for every 10 triggers on its station this Hour.

const TRIGGERS_PER_STEP := 10
const XMULT_PER_STEP := 0.1


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var steps := 0
	if tile != null and tile.map != null:
		steps = floori(float(_get_segment_trigger_count_this_turn(tile)) / float(TRIGGERS_PER_STEP))
	return {
		"additive_mult": _get_production_amount(),
		"multiplicative_mult": 1.0 + XMULT_PER_STEP * float(steps),
	}
