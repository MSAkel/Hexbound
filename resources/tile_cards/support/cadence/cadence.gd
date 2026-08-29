extends TileCard
## If this segment has 7 or more tiles, retrigger every fourth Downstream Producer on the line.

const MIN_SEGMENT_SIZE := 7
const PRODUCER_STEP := 4


func _on_activate_tile_card(tile: Hex) -> void:
	var targets := _get_cadence_targets(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		return
	_try_queue_tile_card_triggers(tile, targets)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_cadence_targets(hover_tile))


func _get_cadence_targets(tile: Hex) -> Array[TileCard]:
	if _get_segment_size(tile) < MIN_SEGMENT_SIZE:
		return []
	var later_producers := _get_later_tile_cards_on_same_segment(tile, TileCardType.PRODUCER)
	var targets: Array[TileCard] = []
	# 4th, 8th, 12th Downstream Producer. Index 3, 7, 11 in the Downstream list.
	var index := PRODUCER_STEP - 1
	while index < later_producers.size():
		targets.append(later_producers[index])
		index += PRODUCER_STEP
	return targets
