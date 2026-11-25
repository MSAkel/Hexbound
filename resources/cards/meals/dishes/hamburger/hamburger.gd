extends MealCard

## +40 Flavour and +4 Mult, +1 Mult for every 10 triggers on its station this Hour. No xMult
## (Meals no longer give it). Untuned.

const BASE_FLAVOUR := 40
const TRIGGERS_PER_STEP := 10
const MULT_PER_STEP := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var steps := 0
	if tile != null and tile.map != null:
		steps = floori(float(_get_segment_trigger_count_this_turn(tile)) / float(TRIGGERS_PER_STEP))
	return {
		"flavour": BASE_FLAVOUR,
		"additive_mult": _get_production_amount() + MULT_PER_STEP * float(steps),
	}
