extends TileCard
## Triggers every card on this station and the next one. Fires once, then spoils.
## Nothing can retrigger it: other cards, staff and chef repeats all skip it.

var _has_fired := false


func can_be_triggered_by_other_card(_tile: Hex = null) -> bool:
	return false


func _on_activate_tile_card(tile: Hex) -> void:
	if _has_fired:
		return
	_has_fired = true

	var on_destroy := func() -> void:
		AudioManager.play_sfx(UISounds.SPOIL_BREAK)
	if not _try_queue_tile_card_triggers(tile, _effect_preview_cards(tile)):
		# Same as the after-triggers path: no Ward save, so it always spoils.
		_destroy_placed_tile_card(tile, self, false)
		on_destroy.call()
		return

	_create_floating_text(tile, "Whoosh!")
	_destroy_placed_tile_card_after_queued_triggers(tile, self, on_destroy)


## Every other card on this station and the next. Never itself, or it would retrigger forever.
func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for card: TileCard in _get_all_tile_cards_on_same_segment(tile):
		if card != self:
			cards.append(card)
	var next_segment := _get_next_segment_index(tile)
	var board := _board(tile)
	if next_segment < 0 or board == null:
		return cards
	for hex: Hex in board.hexes_in_segment(next_segment):
		if hex.active_tile_card != null:
			cards.append(hex.active_tile_card)
	return cards
