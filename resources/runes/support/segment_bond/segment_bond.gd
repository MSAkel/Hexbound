extends Rune

## Adjacent score runes on the same segment permanently gain +10 score
func _on_activate_rune(tile: Hex) -> void:
	var targets := _get_adjacent_same_segment_producers_by_product(tile, Product.SCORE)
	for rune: Rune in targets:
		# Permanent production buff so later activations of that score rune produce more.
		rune.bonus_production_amount += base_production_amount
		var target_hex := tile.map.get_hex_for_rune(rune)
		if target_hex != null:
			_create_floating_text(target_hex, "Gained +%d" % base_production_amount, Color.AQUA)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_adjacent_same_segment_producers_by_product(hover_tile, Product.SCORE)
