extends ChefPerk

## Chef de Cuisine: every station gets both level 3 options and both level 6 options, but every
## station type levels up on slow_thresholds.
@export var slow_thresholds: Array[int] = [3, 7, 11, 16, 21]


func level_thresholds(_station_type: StationType, default_thresholds: Array[int]) -> Array[int]:
	if slow_thresholds.size() == default_thresholds.size():
		return slow_thresholds
	return default_thresholds


func takes_every_station_pick() -> bool:
	return true
