extends StationPerk

## Leche de Tigre: matching Ingredients here gain flat_flavour for each Vegetable on an adjacent
## Cold Station.
const COLD_TYPE_ID := "cold_station"


func flat_flavour_on_station(seg: int, _tile: Hex, card: TileCard) -> int:
	if not matches(card):
		return 0
	var vegetables := 0
	for side: int in StationManager.adjacent_segments(seg):
		if StationManager.get_station_type_id(side) != COLD_TYPE_ID:
			continue
		for other: TileCard in StationManager.station_cards(side):
			if other.has_ingredient_tag(TileCard.TAG_VEGETABLE):
				vegetables += 1
	return flat_flavour * vegetables
