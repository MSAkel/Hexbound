extends StationPerk

## Lemon Wedge: the first matching Ingredient to trigger here each Hour Garnishes a Beverage here.


func after_card_triggered(seg: int, tile: Hex, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.INGREDIENT or not matches(card):
		return
	var state := StationManager.get_state(seg)
	if state.get("hour_lemon_wedge", false):
		return
	for hex: Hex in StationManager.meal_hexes(seg):
		var drink := hex.active_tile_card as MealCard
		if StationManager.meal_counts_as(drink, hex, MealCard.MealCategory.BEVERAGE):
			if StationManager.garnish_from(tile, card, drink):
				state["hour_lemon_wedge"] = true
				return
