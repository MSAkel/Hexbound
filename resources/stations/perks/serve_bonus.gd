extends StationPerk

## Matching Meals served on this station pay extra Gold and/or Mult (Pastry gold, Fish +8 Mult when a
## Sauce Station is present, Roast Potatoes). Mult scales with the Meal's trigger like its own output.
@export var bonus_gold: int = 0
@export var bonus_mult: float = 0.0
## Extra Mult for each Hour played today (Reduction).
@export var bonus_mult_per_hour: float = 0.0
## The bonus only pays while a station of this type is on the board.
@export var requires_type_id: String = ""


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not _meal_matches(tile, meal):
		return
	if not requires_type_id.is_empty() and not StationManager.is_type_present(requires_type_id):
		return
	if bonus_gold > 0:
		meal.add_gold(tile, bonus_gold, false)
	var mult := bonus_mult + bonus_mult_per_hour * float(StationManager.hour_number())
	if not is_zero_approx(mult):
		meal.add_additive_mult(tile, mult)


func _meal_matches(tile: Hex, meal: MealCard) -> bool:
	for category: int in target_meal_categories:
		if StationManager.meal_counts_as(meal, tile, category):
			return true
	return false


## Bonuses pay on serve, so they are not an output scale on the station.
func output_scale_on_station(_seg: int, _tile: Hex, _card: TileCard) -> float:
	return 1.0
