extends MealCard

## +3 Mult, plus the Flavour of the Vegetables on its station.


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	return {
		"flavour": _station_flavour_for_kind(tile, TAG_VEGETABLE, preview),
		"additive_mult": _get_production_amount(),
	}
