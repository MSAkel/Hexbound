extends TileCard
## Breaks target card then gain a random card


func apply_on_placement(tile: Hex) -> void:
	var target := tile.active_tile_card
	if target == null:
		return

	_destroy_placed_tile_card(tile, target)
	AudioManager.play_sfx(UISounds.RUNE_BREAK)

	var drafted := RuneLoot.draw_runes(1, [], true, RunRng.create_card_effect_rng(tile, self, "extract"))
	if drafted.is_empty():
		failed_tile_card_text(tile)
		return

	# Fresh copy so the hand does not share the pool template.
	var hand_copy: TileCard = drafted[0].duplicate(true)
	_add_generated_card_to_hand(hand_copy)
	_create_floating_text(tile, "+ %s" % hand_copy.name)
