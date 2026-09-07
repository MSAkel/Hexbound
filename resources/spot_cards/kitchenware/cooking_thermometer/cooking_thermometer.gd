extends TileCard

## Up to 3 adjacent Following Flavour cards permanently gain +3 Flavour.
func _on_activate_tile_card(tile: Hex) -> void:
	var adjacent_cards: Array[TileCard] = _producers_by_product(
		tile, Product.FLAVOUR, QueryScope.FOLLOWING_ADJACENT
	)
	# Only the first three Following Flavour seats grow. Extra neighbors stay unchanged.
	var buffed := 0
	for card: TileCard in adjacent_cards:
		if buffed >= 3:
			break
		_grow_permanent(tile, card, float(base_production_amount))
		buffed += 1


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_producers_by_product(
		hover_tile, Product.FLAVOUR, QueryScope.FOLLOWING_ADJACENT
	)
