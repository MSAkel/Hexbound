extends TileCard

## Fires the last card of each following station. Must sit on a last station spot.
func _on_activate_tile_card(tile: Hex) -> void:
	_try_queue_tile_card_triggers(tile, _cards_on_later_segment_ends(tile, false))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_later_segment_anchors(hover_tile, false)
