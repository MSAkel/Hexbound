extends MealCard

## Doubles every neighbouring Following Dish-tagged Meal.


func _on_activate_tile_card(tile: Hex) -> void:
	var doubled_any := false
	for card: TileCard in _following_dish_meals(tile):
		var target_hex := tile.map.get_hex_for_tile_card(card) if tile.map != null else null
		if target_hex == null:
			continue
		if not _try_empower_tile_card(tile, card):
			continue
		_create_doubled_floating_text(tile, card)
		doubled_any = true
	if not doubled_any:
		failed_tile_card_text(tile)
		return
	RunLedger.record_dish_plated()


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _stat_board_chip()
	if _following_dish_meals(tile).is_empty():
		return _stat_board_chip()
	return _amount_board_chip(0, ICON_DOUBLE)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _following_dish_meals(hover_tile))


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return get_trigger_preview_coords(hover_tile)


func _following_dish_meals(tile: Hex) -> Array[TileCard]:
	var dishes: Array[TileCard] = []
	for card: TileCard in _get_following_adjacent_tile_cards(tile):
		if card != null and card.has_ingredient_tag(TAG_DISH):
			dishes.append(card)
	return dishes
