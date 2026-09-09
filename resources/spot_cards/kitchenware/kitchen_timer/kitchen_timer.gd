extends TileCard

## On the final hour, double up to three Following Ingredients on this course.
const MAX_TARGETS := 3


func _on_activate_tile_card(tile: Hex) -> void:
	if GameManager.remaining_turns != 1:
		failed_tile_card_text(tile)
		return

	var later_producers := _get_later_tile_cards_on_same_segment(tile, TileCard.PRODUCER_TYPE_FILTER)
	if later_producers.size() > MAX_TARGETS:
		later_producers = later_producers.slice(0, MAX_TARGETS)
	if later_producers.is_empty():
		failed_tile_card_text(tile)
		return

	var empowered_any := false
	for rune in later_producers:
		if not _try_empower_tile_card(tile, rune):
			continue
		empowered_any = true
		_create_doubled_floating_text(tile, rune)

	if not empowered_any:
		failed_tile_card_text(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var targets := _get_later_tile_cards_on_same_segment(hover_tile, TileCard.PRODUCER_TYPE_FILTER)
	if targets.size() > MAX_TARGETS:
		targets = targets.slice(0, MAX_TARGETS)
	return _coords_for_placed_tile_cards(hover_tile, targets)
