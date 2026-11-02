extends ChefPerk

## Pitmaster: stations of station_type_id level up on fast_thresholds. Meals in target_meal_categories
## pay +mult_per_level Mult for each level of the station they are served on.
@export var station_type_id: String = "grilling_station"
@export var fast_thresholds: Array[int] = [1, 3, 4, 6, 8]
@export var target_meal_categories: Array[int] = [MealCard.MealCategory.MEAT, MealCard.MealCategory.POULTRY]
@export var mult_per_level: float = 1.0


func level_thresholds(station_type: StationType, default_thresholds: Array[int]) -> Array[int]:
	if station_type.id == station_type_id and fast_thresholds.size() == default_thresholds.size():
		return fast_thresholds
	return default_thresholds


func meal_extra_mult(_state: Dictionary, tile: Hex, meal: MealCard) -> float:
	if meal == null:
		return 0.0
	var counts := false
	for category: int in target_meal_categories:
		if StationManager.meal_counts_as(meal, tile, category):
			counts = true
			break
	if not counts:
		return 0.0
	var seg := StationManager.segment_of_tile(tile)
	if seg < 0 or StationManager.get_station_type(seg) == null:
		return 0.0
	return mult_per_level * float(StationManager.get_level(seg))
