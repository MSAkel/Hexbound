extends MealCard

## Doubles every neighbouring Following Dish-tagged Meal.


func _on_activate_tile_card(tile: Hex) -> void:
	var doubled_any := false
	for card: TileCard in _effect_preview_cards(tile):
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
	if _effect_preview_cards(tile).is_empty():
		return _stat_board_chip()
	return _amount_board_chip(0, ICON_DOUBLE)


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return get_trigger_preview_coords(hover_tile)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _cards_by_kind(tile, TAG_DISH, QueryScope.FOLLOWING_ADJACENT)
