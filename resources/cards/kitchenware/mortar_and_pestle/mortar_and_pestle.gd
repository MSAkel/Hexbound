extends TileCard

## +2 Mult, +1 Mult if it Seasons an Ingredient. Seasoned: the next Ingredient on its Station also
## counts as a Seasoning, for recipes and "for each" effects (not Station setups). See KitchenwarePrep.

const TARGET_COUNT := 1
const SEASONED_KINDS: Array[StringName] = [TAG_SEASONING]


func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _effect_preview_cards(tile)
	for target: TileCard in targets:
		_create_targeted_ability_floating_text(tile, ICON_FLAVOUR, target)
	_pay_kitchenware_mult(tile, targets.size())


func apply_board_prep(tile: Hex, board: HexBoardQuery) -> void:
	for target: TileCard in board.next_ingredients_on_station(tile, TARGET_COUNT):
		target.grant_kind_tags(SEASONED_KINDS, KitchenwarePrep.STATUS_SEASONED)
		board.mark_prepped(target)


func get_planned_preparations(tile: Hex) -> int:
	return _effect_preview_cards(tile).size()


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.next_ingredients_on_station(tile, TARGET_COUNT)
