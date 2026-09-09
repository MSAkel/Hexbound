extends MealCard

## Gains x0.25 Mult for every neighbouring Dish-tagged Meal.

const MULT_PER_DISH := 0.25


func _on_activate_tile_card(tile: Hex) -> void:
	var dish_count := _adjacent_dish_meals(tile).size()
	if dish_count <= 0:
		failed_tile_card_text(tile)
		return
	multiply_multiplicative_mult(tile, MULT_PER_DISH * float(dish_count))
	RunLedger.record_dish_plated()


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _multiplicative_mult_board_chip(MULT_PER_DISH)
	var dish_count := _adjacent_dish_meals(tile).size()
	if dish_count <= 0:
		return _stat_board_chip()
	return _multiplicative_mult_board_chip(MULT_PER_DISH * float(dish_count))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_cards_by_kind(hover_tile, TAG_DISH, QueryScope.ADJACENT)


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return get_trigger_preview_coords(hover_tile)


func _adjacent_dish_meals(tile: Hex) -> Array[TileCard]:
	return _cards_by_kind(tile, TAG_DISH, QueryScope.ADJACENT)
