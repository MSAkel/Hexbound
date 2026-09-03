extends TileCard
## Swap two placed cards. Choose the first occupied spot, then the second.

func apply_on_targets(tiles: Array[Hex]) -> void:
	if tiles.size() < 2:
		return
	var hex_a := tiles[0]
	var hex_b := tiles[1]
	if hex_a == null or hex_a.map == null:
		return
	# restore_placed_tile_card keeps the existing instances. place_tile_card would duplicate them.
	hex_a.map.swap_placed_tile_cards(hex_a, hex_b)
	_create_floating_text(hex_a, "Swapped")
	_create_floating_text(hex_b, "Swapped")
