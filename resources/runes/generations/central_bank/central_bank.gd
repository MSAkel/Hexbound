extends Rune

# +2 gold, increased by an additional 1 for every adjacent gold prod rune
func _on_activate_rune(tile: Hex) -> void:
	var adjacent_gold_count := 0
	var adjacent_prod_runes: Array[Rune] = _get_all_adjacent_runes(tile, Rune.RuneType.PRODUCER)
	for rune in adjacent_prod_runes:
		if rune.product == Product.GOLD:
			adjacent_gold_count += 1
		 
	add_gold(tile, _get_production_amount() + adjacent_gold_count * 1)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_producers_by_product(hover_tile, Product.GOLD)
