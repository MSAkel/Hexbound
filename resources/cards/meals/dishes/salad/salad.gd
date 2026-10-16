extends MealCard

## +15 Mult, plus the Flavour of the Vegetables on its station x1.5.

const VEGETABLE_SCALE := 1.5


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var vegetable_flavour := _station_flavour_for_kind(tile, TAG_VEGETABLE, preview)
	return {
		"flavour": int(round(float(vegetable_flavour) * VEGETABLE_SCALE)),
		"additive_mult": _get_production_amount(),
	}
