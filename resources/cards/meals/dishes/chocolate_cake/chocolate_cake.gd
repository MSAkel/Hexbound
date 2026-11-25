extends MealCard

## Needs Chocolate and another Sweet. +40 Flavour and +2 Mult, +2 Mult for each different Sweet on
## its station. No xMult (Meals no longer give it). Untuned.

const BASE_FLAVOUR := 40
const MULT_PER_SWEET := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var sweet_count := 1 if tile == null else _different_sweet_count(tile)
	return {
		"flavour": BASE_FLAVOUR,
		"additive_mult": _get_production_amount() + MULT_PER_SWEET * float(sweet_count),
	}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_cards_by_kind(hover_tile, TAG_SWEET, QueryScope.SAME_SEGMENT))
	return coords


func _different_sweet_count(tile: Hex) -> int:
	var ids := {}
	for card: TileCard in _filter_tile_cards_by_kind(_station_cards(tile), TAG_SWEET):
		ids[card.id] = true
	return ids.size()
