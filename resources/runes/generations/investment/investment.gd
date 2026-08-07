extends Rune

# +3 gold for every gold producing rune
func _on_activate_rune(tile: Hex) -> void:
	var gold_producers := _get_producer_count_by_product_type(tile, Product.GOLD)
	var gold_to_add := gold_producers * base_production_amount
	add_gold(tile, gold_to_add)
