extends TileCard
## +5 Flavour for every fire on this course so far this hour

func _on_activate_tile_card(tile: Hex) -> void:
	# Includes this activation
	var trigger_count := _get_segment_trigger_count_this_turn(tile)
	if trigger_count <= 0:
		return
	add_score(tile, _get_production_amount() * trigger_count)


func get_board_chip(tile: Hex = null) -> Dictionary:
	var trigger_count := 0
	if tile != null:
		trigger_count = _get_segment_trigger_count_this_turn(tile)
	# At rest the count is 0. Show the per-trigger rate so the chip is not blank.
	if trigger_count <= 0:
		return _amount_board_chip(_get_production_amount())
	return _amount_board_chip(_get_production_amount() * trigger_count)
