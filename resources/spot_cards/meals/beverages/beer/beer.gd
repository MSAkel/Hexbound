extends MealCard

## Starts at x1 Mult and gains x0.25 for every neighbouring Dish-tagged Meal.
## base_production_amount is the starting xMult so production bonuses scale it consistently.

const MULT_PER_DISH := 0.25


func _on_activate_tile_card(tile: Hex) -> void:
	var factor := _adjacent_dish_xmult(tile)
	if is_zero_approx(factor):
		failed_tile_card_text(tile)
		return
	multiply_multiplicative_mult(tile, factor)
	RunLedger.record_dish_plated()


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _multiplicative_mult_board_chip(float(_get_production_amount()) + MULT_PER_DISH)
	var factor := _adjacent_dish_xmult(tile)
	if is_zero_approx(factor):
		return _stat_board_chip()
	return _multiplicative_mult_board_chip(factor)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_cards_by_kind(hover_tile, TAG_DISH, QueryScope.ADJACENT)


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return get_trigger_preview_coords(hover_tile)


func _adjacent_dish_meals(tile: Hex) -> Array[TileCard]:
	return _cards_by_kind(tile, TAG_DISH, QueryScope.ADJACENT)


func _adjacent_dish_xmult(tile: Hex) -> float:
	var dish_count := _adjacent_dish_meals(tile).size()
	if dish_count <= 0:
		return 0.0
	return float(_get_production_amount()) + MULT_PER_DISH * float(dish_count)
