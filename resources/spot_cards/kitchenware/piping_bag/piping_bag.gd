extends TileCard
## This course +15 Flavour. Next course +2 Mult.

const NEXT_SEGMENT_MULT := 2.0


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())
	var next_segment_index := _get_next_segment_index(tile)
	if next_segment_index < 0:
		return
	add_multiplier_to_segment(tile, next_segment_index, NEXT_SEGMENT_MULT)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_next_segment(hover_tile)
