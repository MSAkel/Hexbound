extends ChefPerk

## Forager: never offered cards with excluded_tags, Meals in excluded_meal_categories, or Meals whose
## recipe needs an excluded kind or card. No output bonus: the smaller pool is the upside.
@export var excluded_tags: Array[StringName] = [TileCard.TAG_MEAT, TileCard.TAG_SEAFOOD]
@export var excluded_meal_categories: Array[int] = [
	MealCard.MealCategory.MEAT, MealCard.MealCategory.POULTRY, MealCard.MealCategory.SEAFOOD,
]


func allows_card(card: TileCard) -> bool:
	if card == null:
		return true
	for tag: StringName in excluded_tags:
		if card.has_ingredient_tag(tag):
			return false
	var meal := card as MealCard
	if meal == null:
		return true
	if int(meal.meal_category) in excluded_meal_categories:
		return false
	if TileCard.TAG_MEAT in excluded_tags and meal.recipe_meat_count > 0:
		return false
	if TileCard.TAG_SEAFOOD in excluded_tags and meal.recipe_seafood_count > 0:
		return false
	for card_id: String in meal.recipe_required_card_ids:
		var template := GameManager.get_tile_card_by_id(card_id)
		if template != null and not allows_card(template):
			return false
	return true
