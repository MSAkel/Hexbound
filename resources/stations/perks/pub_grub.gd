extends StationPerk

## Pub Grub: while a Bar is on the board, each Ingredient trigger here gives every Beer on a Bar
## xmult_per_trigger more xMult for the rest of the Day.
const BAR_TYPE_ID := "bar_station"
@export var xmult_per_trigger: float = 0.05


func after_card_triggered(_seg: int, _tile: Hex, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.INGREDIENT:
		return
	for bar: int in StationManager.segments_of_type(BAR_TYPE_ID):
		for hex: Hex in StationManager.meal_hexes(bar):
			var drink := hex.active_tile_card
			if drink.has_method("add_day_xmult"):
				drink.call("add_day_xmult", xmult_per_trigger)
