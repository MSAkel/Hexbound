extends TileCard
## Adds a random enhancement card to your hand. Breaks after 3 triggers

const MAX_TRIGGERS := 3


func _on_activate_tile_card(tile: Hex) -> void:
	activation_count += 1
	_add_random_enhancement_to_hand(tile)

	if activation_count >= MAX_TRIGGERS:
		_destroy_placed_tile_card(tile, self)
		AudioManager.play_sfx(UISounds.RUNE_BREAK)


func _add_random_enhancement_to_hand(tile: Hex) -> void:
	if GameManager.enhancements_pool.is_empty():
		failed_tile_card_text(tile)
		return

	# Fresh copy so the hand does not share the pool template.
	var template: Enhancement = GameManager.enhancements_pool.pick_random()
	var hand_copy: Enhancement = template.duplicate(true)
	_add_generated_card_to_hand(hand_copy)
	_create_floating_text(tile, "+ %s" % hand_copy.name)
