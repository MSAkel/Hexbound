extends TileCard
## +5 score for every trigger on this segment so far this turn

func _on_activate_tile_card(tile: Hex) -> void:
	# Includes this activation
	var trigger_count := _get_segment_trigger_count_this_turn(tile)
	if trigger_count <= 0:
		return
	add_score(tile, _get_production_amount() * trigger_count)
