extends TileCard
## Fires every card on its course. Spoils immediately

func _on_activate_tile_card(tile: Hex) -> void:
	var host := _activation_host_card(tile)
	var to_trigger: Array[TileCard] = []
	for card: TileCard in _effect_preview_cards(tile):
		# Skip the acting tile. Copied Break Glass would otherwise retrigger Mirror Copy or Imprint forever.
		if card == host:
			continue
		to_trigger.append(card)

	if not _try_queue_tile_card_triggers(tile, to_trigger):
		return

	_create_floating_text(tile, "Shatter!")
	# Shatter the host hex, not the original Break Glass, when this script is copied.
	_destroy_placed_tile_card_after_queued_triggers(
		tile,
		host,
		func() -> void:
			AudioManager.play_sfx(UISounds.SPOIL_BREAK)
	)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_all_tile_cards_on_same_segment(tile)
