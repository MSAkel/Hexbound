extends TileCard
## Retrigger the first Producer in the next segment.

func _on_activate_tile_card(tile: Hex) -> void:
	var target := _get_lead_in_target(tile)
	if target == null:
		failed_tile_card_text(tile)
		return
	_try_queue_tile_card_triggers(tile, [target])


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var target := _get_lead_in_target(hover_tile)
	if target == null:
		var next_segment := _get_next_segment_index(hover_tile)
		if next_segment < 0:
			return []
		var fallback := hover_tile.map.get_first_tile_coords_in_segment(next_segment)
		if fallback == Vector2i(-1, -1):
			return []
		return [fallback]
	return _coords_for_placed_tile_cards(hover_tile, [target])


func _get_lead_in_target(tile: Hex) -> TileCard:
	return _get_first_or_last_tile_card_in_relative_segment(tile, 1, true, TileCard.PRODUCER_TYPE_FILTER)
