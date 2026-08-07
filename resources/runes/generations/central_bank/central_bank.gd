extends Rune

# +2 gold, increased by an additional 2 for every adjacent gold prod rune
func _on_activate_rune(tile: Hex) -> void:
	var adjacent_gold_count := 0
	var adjacent_prod_runes: Array[Rune] = _get_all_adjacent_runes(tile, Rune.RuneType.PRODUCER)
	for rune in adjacent_prod_runes:
		if rune.product == Product.GOLD:
			adjacent_gold_count += 1
		 
	add_gold(tile, base_production_amount + adjacent_gold_count * 2)
