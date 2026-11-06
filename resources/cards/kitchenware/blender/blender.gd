extends TileCard

## +2 Mult, +1 Mult for each Ingredient it Blends. Blended: the next 2 Ingredients on its Station
## each also count as the other's kinds, for recipes and "for each" effects (not Station setups).
## With only one Ingredient after it, nothing is Blended. See KitchenwarePrep.

const TARGET_COUNT := 2


func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _effect_preview_cards(tile)
	if targets.size() < TARGET_COUNT:
		failed_tile_card_text(tile)
		_pay_kitchenware_mult(tile)
		return
	for target: TileCard in targets:
		_create_targeted_ability_floating_text(tile, ICON_FLAVOUR, target)
	_pay_kitchenware_mult(tile, targets.size())


func apply_board_prep(tile: Hex, board: HexBoardQuery) -> void:
	var targets := board.next_ingredients_on_station(tile, TARGET_COUNT)
	if targets.size() < TARGET_COUNT:
		return
	var first_kinds := KitchenwarePrep.printed_recipe_kinds(targets[0])
	var second_kinds := KitchenwarePrep.printed_recipe_kinds(targets[1])
	targets[0].grant_kind_tags(second_kinds, KitchenwarePrep.STATUS_BLENDED)
	targets[1].grant_kind_tags(first_kinds, KitchenwarePrep.STATUS_BLENDED)
	board.mark_prepped(targets[0])
	board.mark_prepped(targets[1])


func get_planned_preparations(tile: Hex) -> int:
	var targets := _effect_preview_cards(tile)
	return targets.size() if targets.size() >= TARGET_COUNT else 0


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var board := _board(tile)
	if board == null:
		return []
	return board.next_ingredients_on_station(tile, TARGET_COUNT)
