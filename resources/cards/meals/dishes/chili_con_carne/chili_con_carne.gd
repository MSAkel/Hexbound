extends MealCard

## Needs a Meat, Chili Flakes and Onion. +4 Mult, plus the Flavour of the Meat on its station x1.5.

const MEAT_SCALE := 1.5


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var meat_flavour := _station_flavour_for_kind(tile, TAG_MEAT, preview)
	return {
		"flavour": int(round(float(meat_flavour) * MEAT_SCALE)),
		"additive_mult": _get_production_amount(),
	}
