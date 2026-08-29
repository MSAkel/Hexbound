extends TileCard

## Trigger the earliest adjacent Downstream card. If every adjacent Downstream hex is occupied by a unique id, trigger all.
func _on_activate_tile_card(tile: Hex) -> void:
	var downstream_hexes := _get_downstream_adjacent_hexes(tile)
	var downstream_cards := _get_downstream_adjacent_tile_cards(tile)
	if downstream_cards.is_empty():
		failed_tile_card_text(tile)
		return

	var to_trigger: Array[TileCard] = []
	if _all_downstream_hexes_have_unique_cards(downstream_hexes, downstream_cards):
		to_trigger = downstream_cards
	else:
		to_trigger.append(downstream_cards[0])

	if not _try_queue_tile_card_triggers(tile, to_trigger):
		return

	_create_floating_text(tile, "Triggered %s" % to_trigger.size())


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_downstream_adjacent_tile_cards(hover_tile))


func _all_downstream_hexes_have_unique_cards(
	downstream_hexes: Array[Hex],
	downstream_cards: Array[TileCard]
) -> bool:
	if downstream_hexes.is_empty():
		return false
	if downstream_cards.size() != downstream_hexes.size():
		return false
	var seen_ids: Dictionary = {}
	for card: TileCard in downstream_cards:
		if seen_ids.has(card.id):
			return false
		seen_ids[card.id] = true
	return true
