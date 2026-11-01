extends StationPerk

## Pairing: Beverages on this station also count as served on the stations on either side.


func shares_beverages_with(seg: int, other_seg: int) -> bool:
	return other_seg in StationManager.adjacent_segments(seg)
