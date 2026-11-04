extends ChefPerk

## Fishmonger, Catch of the Day: at the start of each Day every Ingredient with target_tag on the
## board is Garnished. Like every Garnish it waits for that card's next trigger and clears at Day end.
@export var target_tag: StringName = TileCard.TAG_SEAFOOD


func on_day_started(_state: Dictionary) -> void:
	var board := StationManager.get_board()
	if board == null:
		return
	for hex: Hex in board.get_hexes_in_trigger_order():
		var card := hex.active_tile_card
		if card == null or card.type != TileCard.TileCardType.INGREDIENT:
			continue
		if card.has_ingredient_tag(target_tag):
			card.add_garnish()
