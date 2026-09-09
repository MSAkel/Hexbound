extends TileCard

## Each Double stack on this course adds +1 Mult for the rest of the current Day.

var day_mult_bonus: float = 0.0
var bonus_day: int = -1


func _on_activate_tile_card(tile: Hex) -> void:
	_sync_day_bonus()
	var double_count := _count_double_stacks(tile)
	if double_count > 0:
		day_mult_bonus += _get_production_amount() * float(double_count)
	if is_zero_approx(day_mult_bonus):
		failed_tile_card_text(tile)
		return
	add_additive_mult(tile, day_mult_bonus)


func get_board_chip(tile: Hex = null) -> Dictionary:
	_sync_day_bonus()
	if tile == null and is_zero_approx(day_mult_bonus):
		return _amount_board_chip_float(_get_production_amount(), ICON_MULT)
	var amount := day_mult_bonus
	if tile != null:
		amount += _get_production_amount() * float(_count_double_stacks(tile))
	if is_zero_approx(amount):
		return _stat_board_chip()
	return _amount_board_chip_float(amount, ICON_MULT)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var doubled_cards: Array[TileCard] = []
	if tile == null or tile.map == null:
		return doubled_cards
	for card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		if card.empower_stacks > 0:
			doubled_cards.append(card)
	return doubled_cards


func capture_placed_save_state() -> Dictionary:
	_sync_day_bonus()
	return {
		"day_mult_bonus": day_mult_bonus,
		"bonus_day": bonus_day,
	}


func apply_placed_save_state(data: Dictionary) -> void:
	day_mult_bonus = float(data.get("day_mult_bonus", 0.0))
	bonus_day = int(data.get("bonus_day", GameManager.current_round))
	_sync_day_bonus()


func _count_double_stacks(tile: Hex) -> int:
	var count := 0
	for card: TileCard in _effect_preview_cards(tile):
		count += card.empower_stacks
	return count


func _sync_day_bonus() -> void:
	if bonus_day == GameManager.current_round:
		return
	bonus_day = GameManager.current_round
	day_mult_bonus = 0.0
