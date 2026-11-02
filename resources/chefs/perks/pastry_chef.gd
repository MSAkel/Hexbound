extends ChefPerk

## Pastry Chef: each Meal in meal_category served Garnishes a random Ingredient with target_tag on
## its own station. The Garnish pays off on that card's next trigger.
@export var meal_category: int = MealCard.MealCategory.DESSERT
@export var target_tag: StringName = TileCard.TAG_SWEET


func on_meal_served(_state: Dictionary, tile: Hex, meal: MealCard) -> void:
	if meal == null or not StationManager.meal_counts_as(meal, tile, meal_category):
		return
	if EventManager.are_garnishes_blocked():
		return
	var seg := StationManager.segment_of_tile(tile)
	if seg < 0:
		return
	var candidates: Array[Hex] = []
	for hex: Hex in StationManager.ingredient_hexes(seg):
		var card := hex.active_tile_card
		if card == null or not card.has_ingredient_tag(target_tag):
			continue
		if card.garnish_stacks >= StaffManager.max_garnish_stacks_for(card):
			continue
		candidates.append(hex)
	if candidates.is_empty():
		return
	var pick := candidates[meal._effect_rng(tile, "pastry_chef").randi_range(0, candidates.size() - 1)]
	StationManager.garnish_from(tile, meal, pick.active_tile_card)
