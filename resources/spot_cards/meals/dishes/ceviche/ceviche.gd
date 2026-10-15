extends MealCard

## Needs Lemon. +10 Mult, plus the Flavour of the Seafood on its station x1.5.

const SEAFOOD_SCALE := 1.5


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var seafood_flavour := _station_flavour_for_kind(tile, TAG_SEAFOOD, preview)
	return {
		"flavour": int(round(float(seafood_flavour) * SEAFOOD_SCALE)),
		"additive_mult": _get_production_amount(),
	}
