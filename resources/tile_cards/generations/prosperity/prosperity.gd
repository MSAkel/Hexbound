extends TileCard

## +4 Score per Gold produced earlier in this segment.
func _on_activate_tile_card(tile: Hex) -> void:
	## Gold already credited on this segment before this card resolves.
	var gold_earned := _get_segment_turn_gold(tile)
	add_score(tile, gold_earned * _get_production_amount())
