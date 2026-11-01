extends StationPerk

## Roasting levels: matching Ingredients gain per_hour Flavour for each Hour played today.
@export var per_hour: int = 0


func flat_flavour_on_station(_seg: int, _tile: Hex, card: TileCard) -> int:
	return per_hour * StationManager.hour_number() if matches(card) else 0
