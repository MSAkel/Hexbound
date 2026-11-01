extends StationPerk

## Sauce level 3: each time a Sauce & Dip meal on this station is served, it Garnishes a random Meal
## in target_meal_categories anywhere on the board, stacks times.
@export var stacks: int = 1


func on_meal_served(seg: int, meal_seg: int, tile: Hex, meal: MealCard) -> void:
	if meal_seg != seg or not StationManager.meal_counts_as(meal, tile, MealCard.MealCategory.SAUCE):
		return
	var candidates: Array[Hex] = []
	for other_seg in StationManager.get_station_count():
		for hex: Hex in StationManager.meal_hexes(other_seg):
			var target := hex.active_tile_card as MealCard
			if target == meal or target.garnish_stacks >= StaffManager.max_garnish_stacks_for(target):
				continue
			for category: int in target_meal_categories:
				if StationManager.meal_counts_as(target, hex, category):
					candidates.append(hex)
					break
	if candidates.is_empty():
		return
	var pick := candidates[meal._effect_rng(tile, "sauce_garnish").randi_range(0, candidates.size() - 1)]
	StationManager.sauce_garnish(tile, meal, pick, pick.active_tile_card, stacks)
