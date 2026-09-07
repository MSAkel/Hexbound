extends TileCard
## +2 Mult per other course that contains a Ingredient.

func _on_activate_tile_card(tile: Hex) -> void:
	if _effect_amount(tile) <= 0.0:
		failed_tile_card_text(tile)
		return
	_pay_effect_amount(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_other_segments_matching_producer(hover_tile, true)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	# Each other Producer segment adds base_production_amount Mult (2).
	return _get_production_amount() * float(_count_other_segments_by_producer(tile, true))
