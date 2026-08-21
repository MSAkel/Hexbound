extends TileCard

const DESTROY_CHANCE_PER_ADJACENT := 0.10

# Triggers adjacent prod cards, starting from the one next in trigger order. There is a 10% chance that this tile card will be destroyed for every adjacent tile card
func _on_activate_tile_card(tile: Hex) -> void:
	var adjacent_producers := _get_adjacent_producers_from_trigger_order(tile)
	if adjacent_producers.is_empty():
		return
	
	queue_tile_card_triggers(tile, adjacent_producers)
	
	# Each adjacent producer rolled independently. One failed roll destroys this tile card.
	for _i in range(adjacent_producers.size()):
		if randf() < DESTROY_CHANCE_PER_ADJACENT:
			_destroy_placed_tile_card(tile, self)
			AudioManager.play_sfx(UISounds.RUNE_BREAK)
			break


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_adjacent_producers_from_trigger_order(hover_tile))


# Adjacent producers in trigger order, rotated to start at the next tile card in sequence.
func _get_adjacent_producers_from_trigger_order(tile: Hex) -> Array[TileCard]:
	var ordered := _get_all_adjacent_tile_cards_in_trigger_order(tile, TileCard.TileCardType.PRODUCER)
	if ordered.is_empty():
		return ordered
	
	var hexes := tile.map.get_hexes_in_trigger_order()
	var self_index := hexes.find(tile)
	var start_index := 0
	
	var next_rune := _get_next_tile_card_in_trigger_order(tile)
	if next_rune != null and next_rune in ordered:
		start_index = ordered.find(next_rune)
	else:
		for i in range(ordered.size()):
			var producer_hex := tile.map.get_hex_for_tile_card(ordered[i])
			if hexes.find(producer_hex) > self_index:
				start_index = i
				break
	
	var rotated: Array[TileCard] = []
	for i in range(ordered.size()):
		rotated.append(ordered[(start_index + i) % ordered.size()])
	return rotated
