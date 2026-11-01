extends StationPerk

## Charred Vegetables / Fruit Tart: matching Ingredients on an adjacent partner station also gain
## this station's current level bonus.
@export var partner_type_id: String = ""


func flat_flavour_elsewhere(seg: int, card_seg: int, _tile: Hex, card: TileCard) -> int:
	if not card_seg in StationManager.adjacent_segments(seg):
		return 0
	if StationManager.get_station_type_id(card_seg) != partner_type_id or not matches(card):
		return 0
	return StationManager.get_level_flat_flavour(seg)
