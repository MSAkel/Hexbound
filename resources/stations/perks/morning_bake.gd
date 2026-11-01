extends StationPerk

## Morning Bake: matching Meals start each Day at output_scale and lose decay each Hour, never below x1.
@export var decay_per_hour: float = 0.2


func output_scale_on_station(_seg: int, _tile: Hex, card: TileCard) -> float:
	if not matches(card):
		return 1.0
	return maxf(1.0, output_scale - decay_per_hour * float(StationManager.hour_number() - 1))
