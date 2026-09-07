extends TileCard

## +10 Flavour per Seasoning on this course. Max +40.


const MAX_FLAVOUR := 40


func _on_activate_tile_card(tile: Hex) -> void:
	var amount := _get_segment_seasoning_flavour(tile)
	if amount <= 0:
		return
	add_flavour(tile, amount)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _amount_board_chip(_get_production_amount())
	return _amount_board_chip(_get_segment_seasoning_flavour(tile))


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_tile_cards_by_product(hover_tile, Product.MULTIPLIER)


func _get_segment_seasoning_flavour(tile: Hex) -> int:
	var seasoning_count := _get_all_tile_cards_on_same_segment_by_product(tile, Product.MULTIPLIER).size()
	if seasoning_count <= 0:
		return 0
	var amount := int(round(_get_production_amount() * float(seasoning_count)))
	return mini(amount, MAX_FLAVOUR)
