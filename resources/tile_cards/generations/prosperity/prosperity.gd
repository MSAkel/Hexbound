extends TileCard

## +8 Energy plus +4 Energy per Gold already produced on this segment.

func _on_activate_tile_card(tile: Hex) -> void:
	# Live pile is gold from cards that have already fired this turn.
	add_score(tile, _get_production_amount() + _get_segment_turn_gold(tile) * 4)


func get_board_chip(tile: Hex = null) -> Dictionary:
	# Preview only counts gold cards that fire before this tile. Later gold is not in yet.
	return _amount_board_chip(_get_production_amount() + _get_earlier_segment_gold_preview(tile) * 4)
