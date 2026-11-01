extends StationPerk

## Café: Desserts served here gain mult_per_beverage Mult for each Beverage being served at a Bar.
const BAR_TYPE_ID := "bar_station"
@export var mult_per_beverage: float = 2.0


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.DESSERT):
		return
	var beverages := 0
	for bar: int in StationManager.segments_of_type(BAR_TYPE_ID):
		for hex: Hex in StationManager.meal_hexes(bar):
			var drink := hex.active_tile_card as MealCard
			if drink.is_serving(hex) and StationManager.meal_counts_as(drink, hex, MealCard.MealCategory.BEVERAGE):
				beverages += 1
	if beverages > 0:
		meal.add_additive_mult(tile, mult_per_beverage * float(beverages))
