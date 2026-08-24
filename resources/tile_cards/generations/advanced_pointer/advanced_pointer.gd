extends TileCard

# +15 Energy for every adjacent Energy rune. +50 Energy if all adjacent tiles are Energy runes
func _on_activate_tile_card(_tile: Hex) -> void:
	var adjacent_generators_count = _count_all_occupied_adjacent_tile_cards(_tile, TileCard.TileCardType.PRODUCER)
	if adjacent_generators_count > 0:
		var score_to_add = 15 * adjacent_generators_count
		if adjacent_generators_count == 5:
			score_to_add += 50
		add_score(_tile, score_to_add)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(base_production_amount)
	var adjacent_generators_count := _count_all_occupied_adjacent_tile_cards(tile, TileCardType.PRODUCER)
	if adjacent_generators_count <= 0:
		return _hidden_board_chip()
	var score_to_add := base_production_amount * adjacent_generators_count
	if adjacent_generators_count == 5:
		score_to_add += 50
	return _amount_board_chip(score_to_add)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_tile_cards_by_product(hover_tile, Product.SCORE)
