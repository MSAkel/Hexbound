extends TileCard

## Up to 3 adjacent score runes permanently gain +3 score
func _on_activate_tile_card(tile: Hex) -> void:
	var adjacent_cards: Array[TileCard] = _get_adjacent_tile_cards_by_product(tile, Product.SCORE)
	for card: TileCard in adjacent_cards:
		card.bonus_production_amount += base_production_amount
		card._create_floating_text(tile, "Gained +%d" % base_production_amount, Color.AQUA)

func get_trigger_preview_coords(tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_tile_cards_by_product(tile, Product.SCORE)
