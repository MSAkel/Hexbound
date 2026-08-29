extends TileCard

## Lowest Downstream Energy producer gains +5 Energy permanently.
func _on_activate_tile_card(tile: Hex) -> void:
	var target := _get_lowest_later_score_producer(tile)
	if target == null:
		failed_tile_card_text(tile)
		return

	target.bonus_production_amount += base_production_amount
	var target_hex := tile.map.get_hex_for_tile_card(target)
	if target_hex != null:
		_create_floating_text(target_hex, "Gained +%d" % base_production_amount, Color.AQUA)
		target_hex.refresh_tile_card_visual_state()


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var target := _get_lowest_later_score_producer(hover_tile)
	if target == null:
		return []
	return _coords_for_placed_tile_cards(hover_tile, [target])


func _get_lowest_later_score_producer(tile: Hex) -> TileCard:
	var self_index := tile.map._get_hex_trigger_order_index(tile)
	var lowest: TileCard = null
	var lowest_amount := 0.0
	for hex: Hex in tile.map.get_hexes_in_trigger_order():
		if tile.map._get_hex_trigger_order_index(hex) <= self_index:
			continue
		if not tile.map.is_tile_card_triggerable(hex):
			continue
		var card := hex.active_tile_card
		if card == null:
			continue
		if card.type != TileCardType.PRODUCER:
			continue
		if card.product != Product.SCORE:
			continue

		var amount := card._get_production_amount()
		if lowest == null or amount < lowest_amount:
			lowest = card
			lowest_amount = amount
	return lowest
