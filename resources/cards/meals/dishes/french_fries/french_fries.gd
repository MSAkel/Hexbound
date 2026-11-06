extends MealCard

## Needs Potato and Salt. +3 Mult, plus +1 Mult for each extra trigger a Deep Fryer on its station
## gives this Hour, plus +2 Mult for each Protein dish (Meat, Poultry or Seafood) being served on the
## stations either side of its own.

const MULT_PER_PROTEIN := 2.0
const MULT_PER_FRY := 1.0


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	var mult := _get_production_amount() + MULT_PER_FRY * float(_deep_fryer_triggers(tile, preview))
	return {"additive_mult": mult + MULT_PER_PROTEIN * float(_serving_neighbour_proteins(tile).size())}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _meals_as_tile_cards(_serving_neighbour_proteins(hover_tile))))
	return coords


func _serving_neighbour_proteins(tile: Hex) -> Array[MealCard]:
	var proteins: Array[MealCard] = []
	for meal: MealCard in _neighbour_station_meals(tile, true):
		if meal.is_protein():
			proteins.append(meal)
	return proteins
