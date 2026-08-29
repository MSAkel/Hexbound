extends TileCard

## Adjacent Downstream Energy cards on the same segment permanently gain +10 Energy.
func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _get_downstream_same_segment_producers_by_product(tile, Product.SCORE)
	for rune: TileCard in targets:
		rune.bonus_production_amount += base_production_amount
		var target_hex := tile.map.get_hex_for_tile_card(rune)
		if target_hex != null:
			_create_floating_text(target_hex, "Gained +%d" % base_production_amount, Color.AQUA)
			target_hex.refresh_tile_card_visual_state()


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_downstream_same_segment_producers_by_product(hover_tile, Product.SCORE)
