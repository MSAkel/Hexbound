extends TileCard

## +2 Mult, +1 Mult if it Passes an Ingredient. Passed: the next Ingredient on its Station also
## counts on the next Station down, for that Station's Meals (recipes and their effects). Its
## Flavour is only paid at home, and it does not count toward the lower Station's setup.
## The bottom Station has nowhere to pass. See KitchenwarePrep.

const TARGET_COUNT := 1


func _on_activate_tile_card(tile: Hex) -> void:
	var passed := _passed_cards(tile)
	if passed.is_empty():
		failed_tile_card_text(tile)
	for target: TileCard in passed:
		_create_targeted_ability_floating_text(tile, ICON_FLAVOUR, target)
	_pay_kitchenware_mult(tile, passed.size())


func apply_board_prep(tile: Hex, board: HexBoardQuery) -> void:
	for target: TileCard in board.next_ingredients_on_station(tile, TARGET_COUNT):
		board.pass_card_down(tile, target)


func get_planned_preparations(tile: Hex) -> int:
	return _passed_cards(tile).size()


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _passed_cards(hover_tile))


## The Ingredient it passes, or nothing on the bottom Station.
func _passed_cards(tile: Hex) -> Array[TileCard]:
	var board := _board(tile)
	if board == null or _get_next_segment_index(tile) < 0:
		return []
	return board.next_ingredients_on_station(tile, TARGET_COUNT)
