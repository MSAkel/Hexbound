extends TileCard
## Relay 30% of this segment's Energy pile so far to the next segment.

const RELAY_FRACTION := 0.3


func _on_activate_tile_card(tile: Hex) -> void:
	var next_segment_index := _get_next_segment_index(tile)
	if next_segment_index < 0:
		failed_tile_card_text(tile)
		return
	var relayed := int(round(float(_get_segment_turn_score(tile)) * RELAY_FRACTION))
	if relayed <= 0:
		failed_tile_card_text(tile)
		return
	add_score_to_segment(tile, next_segment_index, relayed)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_next_segment(hover_tile)
