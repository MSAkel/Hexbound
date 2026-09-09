extends TileCard

## Grants +2 additive Mult for every placed Protein-tagged card.


func _on_activate_tile_card(tile: Hex) -> void:
	if is_zero_approx(_effect_amount(tile)):
		failed_tile_card_text(tile)
		return
	_pay_effect_amount(tile)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	return _get_production_amount() * float(_effect_preview_cards(tile).size())


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _cards_by_kind(tile, TAG_PROTEIN, QueryScope.PLACED)
