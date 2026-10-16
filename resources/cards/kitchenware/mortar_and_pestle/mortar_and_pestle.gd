extends TileCard

## +1 Mult. Pays the base output of the 2 Ingredients directly before it. Empty spots count as nothing.

const COPY_COUNT := 2


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	var copied := _effect_preview_cards(tile)
	if copied.is_empty():
		failed_tile_card_text(tile)
		return
	for card: TileCard in copied:
		_create_targeted_ability_floating_text(tile, ICON_FLAVOUR, card)
		add_flavour(tile, card._get_production_amount())


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _effect_preview_cards(hover_tile))


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for card: TileCard in _get_tile_cards_on_immediately_previous_hexes(tile, COPY_COUNT):
		if card.type == TileCardType.INGREDIENT and card.product == Product.FLAVOUR:
			cards.append(card)
	return cards
