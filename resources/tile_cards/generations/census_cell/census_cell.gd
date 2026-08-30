extends TileCard
## +12 Energy per segment on the map.

func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_census_amount(tile))


func get_board_chip(tile: Hex = null) -> Dictionary:
	return _amount_board_chip(_get_census_amount(tile))


func _get_census_amount(tile: Hex) -> float:
	var segments := 0
	if tile != null:
		segments = _get_segment_count(tile)
	elif GameManager.selected_character != null:
		segments = GameManager.selected_character.segments_count
	if segments <= 0:
		return _get_production_amount()
	return _get_production_amount() * float(segments)
