extends StationPerk

## Pub Grub: while a Bar is on the board, each Ingredient trigger here gives every Beer on a Bar
## mult_per_trigger more +Mult for the rest of the Day. Untuned.
const BAR_TYPE_ID := "bar_station"
@export var mult_per_trigger: float = 0.5


func after_card_triggered(_seg: int, _tile: Hex, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.INGREDIENT:
		return
	for bar: int in StationManager.segments_of_type(BAR_TYPE_ID):
		for hex: Hex in StationManager.meal_hexes(bar):
			var drink := hex.active_tile_card
			if drink.has_method("add_day_mult"):
				drink.call("add_day_mult", mult_per_trigger)
