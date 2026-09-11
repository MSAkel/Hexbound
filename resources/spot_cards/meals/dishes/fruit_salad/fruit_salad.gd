extends MealCard

## Gains x0.5 Mult for every adjacent fruit. That x is multiplicative_mult, not additive +Mult.
## base_production_amount is the starting xMult. Each adjacent fruit adds x0.5 on top.

const MULT_PER_FRUIT := 0.5


func _on_activate_tile_card(tile: Hex) -> void:
	var factor := _adjacent_fruit_xmult(tile)
	if is_zero_approx(factor):
		failed_tile_card_text(tile)
		return
	multiply_multiplicative_mult(tile, factor)
	RunLedger.record_dish_plated()


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _multiplicative_mult_board_chip(float(_get_production_amount()) + MULT_PER_FRUIT)
	var factor := _adjacent_fruit_xmult(tile)
	if is_zero_approx(factor):
		return _stat_board_chip()
	return _multiplicative_mult_board_chip(factor)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_cards_by_kind(hover_tile, TAG_FRUIT, QueryScope.ADJACENT)


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	return get_trigger_preview_coords(hover_tile)


func _adjacent_fruit_xmult(tile: Hex) -> float:
	var fruit_count := _get_adjacent_fruit_cards(tile).size()
	if fruit_count <= 0:
		return 0.0
	return float(_get_production_amount()) + MULT_PER_FRUIT * float(fruit_count)


func _get_adjacent_fruit_cards(tile: Hex) -> Array[TileCard]:
	return _cards_by_kind(tile, TAG_FRUIT, QueryScope.ADJACENT)
