extends MealCard

## Gains +x0.1 course Mult for every complete set of 15 fires this Hour.
## MealCard owns the Protein + Seasoning + Kitchenware prefix recipe check.

const TRIGGERS_PER_XMULT_STEP := 15
const XMULT_PER_STEP := 0.1
const BASE_XMULT := 1.0


func _plated_multiplicative_mult_from_recipe(_recipe: Array[TileCard]) -> float:
	return _current_xmult_factor()


func _preview_plated_multiplicative_mult(tile: Hex) -> float:
	if not is_recipe_ready(tile):
		return 0.0
	return _current_xmult_factor()


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _multiplicative_mult_board_chip(BASE_XMULT + XMULT_PER_STEP)
	if not is_recipe_ready(tile):
		return _stat_board_chip()

	var factor := _current_xmult_factor()
	if not is_zero_approx(factor):
		return _multiplicative_mult_board_chip(factor)

	var progress := GameManager.get_current_turn_trigger_count() % TRIGGERS_PER_XMULT_STEP
	return _make_board_chip(
		BoardChipMode.PROGRESS,
		"%d/%d" % [progress, TRIGGERS_PER_XMULT_STEP],
		ICON_FIRE,
		get_chip_panel_color(),
		"Hour fires until x%.1f Mult" % (BASE_XMULT + XMULT_PER_STEP)
	)


func _current_xmult_factor() -> float:
	var completed_steps := floori(
		float(GameManager.get_current_turn_trigger_count()) / float(TRIGGERS_PER_XMULT_STEP)
	)
	if completed_steps <= 0:
		return 0.0
	return BASE_XMULT + XMULT_PER_STEP * float(completed_steps)
