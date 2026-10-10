extends TileCard
## Fire again the first Ingredient in the next station.

func _on_activate_tile_card(tile: Hex) -> void:
	var later_firsts := _cards_on_later_segment_ends(tile, true, TileCard.PRODUCER_TYPE_FILTER)
	if later_firsts.is_empty():
		failed_tile_card_text(tile)
		return
	_try_queue_tile_card_triggers(tile, [later_firsts[0]])


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := _coords_for_later_segment_anchors(
		hover_tile, true, TileCard.PRODUCER_TYPE_FILTER
	)
	if coords.is_empty():
		return []
	return [coords[0]]
