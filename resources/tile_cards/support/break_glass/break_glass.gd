extends TileCard
## Triggers every card on its segment. Breaks immediately

func _on_activate_tile_card(tile: Hex) -> void:
	var segment_cards := _get_all_tile_cards_on_same_segment(tile)
	var to_trigger: Array[TileCard] = []
	for card: TileCard in segment_cards:
		# Skip self so this card cannot retrigger and loop forever.
		if card == self:
			continue
		to_trigger.append(card)

	if not to_trigger.is_empty():
		queue_tile_card_triggers(tile, to_trigger)
		_create_floating_text(tile, "Shatter!")
		_destroy_placed_tile_card_after_queued_triggers(
			tile,
			self,
			func() -> void:
				AudioManager.play_sfx(UISounds.RUNE_BREAK)
		)
	else:
		failed_tile_card_text(tile)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_tile_cards(hover_tile)
