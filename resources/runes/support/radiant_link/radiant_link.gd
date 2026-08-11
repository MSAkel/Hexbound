extends Rune

## Up to 3 adjacent score runes permanently gain +3 score
func _on_activate_rune(tile: Hex) -> void:
	var adjacent_runes: Array[Rune] = _get_adjacent_runes_by_product(tile, Product.SCORE)
	for rune: Rune in adjacent_runes:
		rune.bonus_production_amount += base_production_amount
		rune._create_floating_text(tile, "Gained +%d" % base_production_amount, Color.AQUA)

func get_trigger_preview_coords(tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_runes_by_product(tile, Product.SCORE)
