extends TileCard

# +4 Mult increased by 1 for each Mult rune on the same segment
func _on_activate_tile_card(_tile: Hex) -> void:
	var mult_count := _get_all_tile_cards_on_same_segment_by_product(_tile, Product.MULTIPLIER).size()
	add_multiplier(_tile, mult_count + _get_production_amount())


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_tile_cards_by_product(hover_tile, Product.MULTIPLIER)
