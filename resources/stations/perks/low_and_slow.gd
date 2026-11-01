extends StationPerk

## Low and Slow: a Meal that has been on this station since the start of the Day gains output_scale.
## Meals here when the Day starts are remembered by seat and card.


func output_scale_on_station(seg: int, tile: Hex, card: TileCard) -> float:
	if not card is MealCard:
		return 1.0
	var veterans: Array = StationManager.get_state(seg).get("veterans", [])
	return output_scale if _key(tile, card) in veterans else 1.0


func on_day_started(seg: int) -> void:
	var veterans: Array = []
	for hex: Hex in StationManager.meal_hexes(seg):
		veterans.append(_key(hex, hex.active_tile_card))
	StationManager.get_state(seg)["veterans"] = veterans


func _key(tile: Hex, card: TileCard) -> String:
	return "%d,%d:%s" % [tile.coordinates.x, tile.coordinates.y, card.id]
