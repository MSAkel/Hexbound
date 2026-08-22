extends TileCard
## Gives the next segment +5 Mult

func _on_activate_tile_card(tile: Hex) -> void:
	var next_segment_index := _get_next_segment_index(tile)
	if next_segment_index < 0:
		failed_tile_card_text(tile)
		return
	add_multiplier_to_segment(tile, next_segment_index, _get_production_amount())


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_next_segment(hover_tile)
