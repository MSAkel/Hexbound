extends TileCard

## The Following Flavour permanently gains +10
func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _producers_by_product(tile, Product.FLAVOUR, QueryScope.FOLLOWING_SAME_SEGMENT)
	for rune: TileCard in targets:
		_grow_permanent(tile, rune, float(base_production_amount))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_producers_by_product(
		hover_tile, Product.FLAVOUR, QueryScope.FOLLOWING_SAME_SEGMENT
	)
