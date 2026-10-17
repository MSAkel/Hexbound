extends TileCard

## +1 Mult, plus +1 Mult for each different kind of Ingredient on this Station (Vegetable, Fruit, Meat...).

const PER_KIND := 1.0


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	return _get_production_amount() + PER_KIND * float(_station_kinds(tile).size())


func get_board_chip(tile: Hex = null) -> Dictionary:
	var chip := _amount_board_chip_float(_effect_amount(tile) * star_output_scale(), ICON_MULT)
	var role_texture := FeastStatIcons.get_support_icon(support_role)
	if role_texture != null:
		chip = _compose_board_chip(chip, role_texture)
	return chip


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_all_tile_cards_on_same_segment(tile, TileCardType.INGREDIENT)


func _station_kinds(tile: Hex) -> Dictionary:
	var kinds := {}
	for card: TileCard in _effect_preview_cards(tile):
		for tag: StringName in card.ingredient_tags:
			if tag in RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
