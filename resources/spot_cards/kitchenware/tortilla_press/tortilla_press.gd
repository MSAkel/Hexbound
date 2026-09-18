extends TileCard

## Fires the first card of each following course. Must sit on a first course spot.
func _on_activate_tile_card(tile: Hex) -> void:
	_try_queue_tile_card_triggers(tile, _cards_on_later_segment_ends(tile, true))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_later_segment_anchors(hover_tile, true)
