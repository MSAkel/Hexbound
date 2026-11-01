extends StationPerk

## Side of Roast: Meals on this station gain output_scale while a partner station is adjacent.
@export var partner_type_id: String = ""


func output_scale_on_station(seg: int, _tile: Hex, card: TileCard) -> float:
	if card is MealCard and StationManager.is_type_adjacent(seg, partner_type_id):
		return output_scale
	return 1.0
