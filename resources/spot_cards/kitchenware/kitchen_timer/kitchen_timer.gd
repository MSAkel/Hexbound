extends TileCard

## On the final hour, double up to three Following Ingredients on this course.
const MAX_TARGETS := 3


func _on_activate_tile_card(tile: Hex) -> void:
	if GameManager.remaining_turns != 1:
		failed_tile_card_text(tile)
		return

	var later_producers := _effect_preview_cards(tile)
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


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var later_producers := _get_later_tile_cards_on_same_segment(tile, TileCard.PRODUCER_TYPE_FILTER)
	if later_producers.size() > MAX_TARGETS:
		return later_producers.slice(0, MAX_TARGETS)
	return later_producers
