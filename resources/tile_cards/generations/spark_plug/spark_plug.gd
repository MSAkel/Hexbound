extends TileCard
## +18 Energy. +4 if an adjacent Downstream hex is empty.

const EMPTY_DOWNSTREAM_BONUS := 4


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_spark_plug_amount(tile))


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(_get_production_amount())
	return _amount_board_chip(_get_spark_plug_amount(tile))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for hex: Hex in _get_downstream_adjacent_hexes(hover_tile):
		if hex.is_disabled_by_difficulty:
			continue
		if hex.active_tile_card != null:
			continue
		coords.append(hex.coordinates)
	return coords


func _get_spark_plug_amount(tile: Hex) -> float:
	var amount := _get_production_amount()
	if _has_empty_downstream_hex(tile):
		amount += float(EMPTY_DOWNSTREAM_BONUS)
	return amount


func _has_empty_downstream_hex(tile: Hex) -> bool:
	for hex: Hex in _get_downstream_adjacent_hexes(tile):
		if hex.is_disabled_by_difficulty:
			continue
		if hex.active_tile_card == null:
			return true
	return false
