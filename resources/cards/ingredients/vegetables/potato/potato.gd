extends TileCard

## +5 Flavour for each different kind of Ingredient next to it (Vegetable, Fruit, Meat...).

const PER_KIND := 5.0


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	return _get_production_amount() + PER_KIND * float(_adjacent_kinds(tile).size())


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_all_adjacent_tile_cards(tile, TileCardType.INGREDIENT)


func _adjacent_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _effect_preview_cards(tile):
		for tag: StringName in card.ingredient_tags:
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
