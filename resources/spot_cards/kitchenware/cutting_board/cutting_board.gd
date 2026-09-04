extends TileCard
## Adds a random common card to your hand. Spoils after 3 fires

const MAX_TRIGGERS := 3


func _on_activate_tile_card(tile: Hex) -> void:
	activation_count += 1
	_add_random_common_tile_card_to_hand(tile)

	if activation_count >= MAX_TRIGGERS:
		_destroy_placed_tile_card(tile, self)
		AudioManager.play_sfx(UISounds.SPOIL_BREAK)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _make_board_chip(
		BoardChipMode.PROGRESS,
		"%d/%d" % [activation_count, MAX_TRIGGERS],
		null,
		get_chip_panel_color(),
		"Fires until this card spoils"
	)


func capture_placed_save_state() -> Dictionary:
	return {"activation_count": activation_count}


func apply_placed_save_state(data: Dictionary) -> void:
	activation_count = int(data.get("activation_count", 0))


func _add_random_common_tile_card_to_hand(tile: Hex) -> void:
	# Omit this template so the board cannot replicate itself.
	var pool: Array[TileCard] = []
	for template: TileCard in GameManager.tile_cards_pool:
		if template.id != id:
			pool.append(template)

	var drafted := CardLoot.draw_filtered(
		1,
		pool,
		TileCard.TileCardRarity.COMMON,
		null,
		true,
		null,
		RunRng.create_card_effect_rng(tile, self, "replicate")
	)
	if drafted.is_empty():
		failed_tile_card_text(tile)
		return

	# Fresh copy so the hand does not share the pool template.
	var hand_copy: TileCard = drafted[0].duplicate(true)
	_add_generated_card_to_hand(hand_copy)
	_create_floating_text(tile, "+ %s" % hand_copy.name)
