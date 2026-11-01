extends StationPerk

## Sunday Roast: a Garnish a Sauce & Dip meal on an adjacent Sauce Station gives to a Meal here counts
## as extra_stacks more stacks.
const SAUCE_TYPE_ID := "sauce_station"
@export var extra_stacks: int = 1


func extra_sauce_garnish_stacks(seg: int, source_seg: int) -> int:
	if source_seg in StationManager.adjacent_segments(seg) and StationManager.get_station_type_id(source_seg) == SAUCE_TYPE_ID:
		return extra_stacks
	return 0
