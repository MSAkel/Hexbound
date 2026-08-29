extends TileCard
## +10 Energy, plus +5 per consecutive Energy Producer immediately before this card.

const STREAK_BONUS := 5


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_run_on_amount(tile))


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(_get_production_amount())
	return _amount_board_chip(_get_run_on_amount(tile))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_consecutive_previous_energy_producers(hover_tile))


func _get_run_on_amount(tile: Hex) -> float:
	var streak := _get_consecutive_previous_energy_producers(tile).size()
	return _get_production_amount() + float(STREAK_BONUS * streak)


func _get_consecutive_previous_energy_producers(tile: Hex) -> Array[TileCard]:
	var streak: Array[TileCard] = []
	var hexes := tile.map.get_hexes_in_trigger_order()
	var self_index := tile.map._get_hex_trigger_order_index(tile)
	if self_index < 0:
		return streak
	# Walk the previous hexes. Empty tiles and non-Energy cards break the run.
	for i in range(self_index - 1, -1, -1):
		var card := hexes[i].active_tile_card
		if card == null:
			break
		if card.type != TileCardType.PRODUCER or card.product != Product.SCORE:
			break
		streak.append(card)
	return streak
