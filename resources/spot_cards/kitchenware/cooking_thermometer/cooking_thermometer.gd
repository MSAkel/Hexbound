extends TileCard

## Up to 3 adjacent Following Flavour cards permanently gain +3 Flavour.
func _on_activate_tile_card(tile: Hex) -> void:
	var adjacent_cards: Array[TileCard] = _get_following_adjacent_tile_cards_by_product(tile, Product.SCORE)
	var buffed := 0
	for card: TileCard in adjacent_cards:
		if buffed >= 3:
			break
		card.bonus_production_amount += base_production_amount
		var target_hex := tile.map.get_hex_for_tile_card(card)
		if target_hex != null:
			_create_floating_text(target_hex, "Gained +%d" % base_production_amount, Color.AQUA)
			target_hex.refresh_tile_card_visual_state()
		buffed += 1


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_following_adjacent_tile_cards_by_product(hover_tile, Product.SCORE)
