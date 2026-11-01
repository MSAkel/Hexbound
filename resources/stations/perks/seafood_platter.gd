extends StationPerk

## Seafood Platter: matching output here gains per_kind for each different Seafood on the station.
@export var per_kind: float = 0.25


func output_scale_on_station(seg: int, _tile: Hex, card: TileCard) -> float:
	if card.type != TileCard.TileCardType.INGREDIENT or not matches(card):
		return 1.0
	var ids := {}
	for other: TileCard in StationManager.station_cards(seg):
		if other.type == TileCard.TileCardType.INGREDIENT and other.has_ingredient_tag(TileCard.TAG_SEAFOOD):
			ids[other.id] = true
	return 1.0 + per_kind * float(ids.size())
