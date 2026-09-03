extends TileCard
## Fire again one adjacent Following card in this course. Twice if that card shares this rarity.

func _on_activate_tile_card(tile: Hex) -> void:
	var target := _get_pair_bond_target(tile)
	if target == null:
		failed_tile_card_text(tile)
		return
	var to_trigger: Array[TileCard] = [target]
	if target.rarity == rarity:
		to_trigger.append(target)
	_try_queue_tile_card_triggers(tile, to_trigger)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var target := _get_pair_bond_target(hover_tile)
	if target == null:
		return []
	return _coords_for_placed_tile_cards(hover_tile, [target])


func _get_pair_bond_target(tile: Hex) -> TileCard:
	var segment_index := _get_segment_index(tile)
	# Adjacent Following helpers are earliest-first. Take the first neighbor that shares this segment.
	for card: TileCard in _get_following_adjacent_tile_cards(tile):
		var hex := tile.map.get_hex_for_tile_card(card)
		if hex == null:
			continue
		if tile.map.get_segment_index(hex.coordinates) != segment_index:
			continue
		return card
	return null
