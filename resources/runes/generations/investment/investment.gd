extends Rune

# +3 gold for every gold producing rune
func _on_activate_rune(tile: Hex) -> void:
	var gold_producers := get_producer_count(tile, Product.GOLD)
	var gold_to_add := gold_producers * score_value
	GoldManager.add(gold_to_add)
	create_floating_text(tile, "+%d gold" % gold_to_add)
