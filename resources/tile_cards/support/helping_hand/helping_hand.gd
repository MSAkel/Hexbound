extends TileCard
## Gives the lowest Energy producer +5 permanently

func _on_activate_tile_card(tile: Hex) -> void:
	var target := _get_lowest_score_producer(tile)
	if target == null:
		failed_tile_card_text(tile)
		return

	target.bonus_production_amount += base_production_amount
	var target_hex := tile.map.get_hex_for_tile_card(target)
	if target_hex != null:
		_create_floating_text(target_hex, "Gained +%d" % base_production_amount, Color.AQUA)
		target_hex.refresh_tile_card_visual_state()


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var target := _get_lowest_score_producer(hover_tile)
	if target == null:
		return []
	return _coords_for_placed_tile_cards(hover_tile, [target])


# Among Energy producers, pick the lowest current output. Ties go to the earliest in trigger order.
func _get_lowest_score_producer(tile: Hex) -> TileCard:
	var lowest: TileCard = null
	var lowest_amount := 0
	for hex: Hex in tile.map.get_hexes_in_trigger_order():
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
