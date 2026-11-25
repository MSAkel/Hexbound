extends MealCard

## Needs 2 Fruit. +40 Flavour and +2 Mult, +1 Mult for every Fruit on its station.
## No xMult (Meals no longer give it). Untuned.

const BASE_FLAVOUR := 40
const MULT_PER_FRUIT := 1.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var fruit_count := _count_station_cards_by_kind(tile, TAG_FRUIT)
	if tile == null:
		fruit_count = 1
	return {
		"flavour": BASE_FLAVOUR,
		"additive_mult": _get_production_amount() + MULT_PER_FRUIT * float(fruit_count),
	}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_cards_by_kind(hover_tile, TAG_FRUIT, QueryScope.SAME_SEGMENT)
