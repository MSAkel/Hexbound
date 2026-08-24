extends TileCard

## +3 gold for every gold producing rune on its segment
func _on_activate_tile_card(tile: Hex) -> void:
	var gold_producers := _get_all_tile_cards_on_same_segment_by_product(tile, Product.GOLD)
	var gold_producers_count := gold_producers.size()
	var gold_to_add := gold_producers_count * _get_production_amount()
	add_gold(tile, gold_to_add)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(_get_production_amount())
	var gold_producers_count := _get_all_tile_cards_on_same_segment_by_product(tile, Product.GOLD).size()
	return _amount_board_chip(gold_producers_count * _get_production_amount())


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_producers_by_product(hover_tile, Product.GOLD)
