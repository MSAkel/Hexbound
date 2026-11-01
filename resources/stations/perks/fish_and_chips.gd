extends StationPerk

## Fish & Chips: while a Fish Station is adjacent, Seafood meals on this station also count as Sides.
const FISH_TYPE_ID := "fish_station"


func meal_counts_as(seg: int, meal: MealCard, category: int) -> bool:
	return (
		category == MealCard.MealCategory.SIDE
		and meal.meal_category == MealCard.MealCategory.SEAFOOD
		and StationManager.is_type_adjacent(seg, FISH_TYPE_ID)
	)
