extends TileCard
## +10 Flavour per other station that has no Ingredient.

func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile, true)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_other_segments_matching_producer(hover_tile, false)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	return _get_production_amount() * float(_count_other_segments_by_producer(tile, false))
