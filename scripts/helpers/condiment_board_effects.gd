class_name CondimentBoardEffects
extends RefCounted

## Instant board edits that used to live on Utility hand cards.


static func throw_out(tile: Hex, rng: RandomNumberGenerator) -> bool:
	var target := tile.active_tile_card
	if target == null:
		return false

	destroy_placed_at(tile, target, true)
	AudioManager.play_sfx(UISounds.SPOIL_BREAK)

	var drafted := CardLoot.card_draw(1, [], true, rng)
	if drafted.is_empty():
		_show_failure(tile)
		return false

	var hand_copy: TileCard = drafted[0].duplicate(true)
	EventBus.generated_hand_card.emit(hand_copy)
	_show_text(tile, "+ %s" % hand_copy.name)
	return true


## Returns one ★1 copy per star, so a ★3 card comes back as three copies.
static func send_back(tile: Hex) -> bool:
	var target := tile.active_tile_card
	if target == null:
		return false

	for _copy in target.star_level:
		copy_placed_to_hand(target)
	tile.remove_tile_card()
	_show_text(tile, "Returned!")
	return true


static func duplicate_order(tile: Hex) -> bool:
	if tile.active_tile_card == null:
		return false

	copy_placed_to_hand(tile.active_tile_card)
	_show_text(tile, "Copied!")
	return true


static func swap_spots(hex_a: Hex, hex_b: Hex) -> bool:
	if hex_a == null or hex_b == null or hex_a.map == null:
		return false
	if hex_a.active_tile_card == null or hex_b.active_tile_card == null:
		return false
	# Meals and Meal slots stay paired.
	if not hex_a.active_tile_card.can_place_on_tile(hex_b) or not hex_b.active_tile_card.can_place_on_tile(hex_a):
		_show_failure(hex_a)
		return false
	hex_a.map.swap_placed_tile_cards(hex_a, hex_b)
	_show_text(hex_a, "Swapped")
	_show_text(hex_b, "Swapped")
	return true


static func copy_placed_to_hand(source_card: TileCard) -> void:
	var hand_copy: TileCard = source_card.duplicate(true)
	hand_copy.activation_count = 0
	hand_copy.is_garnished = false
	hand_copy.is_active = true
	hand_copy.star_level = 1
	EventBus.tile_card_selected.emit(hand_copy)


## A duplicate played onto its own card, or Star Up. The seated instance keeps its state and gains a star.
static func star_up_placed_at(tile: Hex) -> void:
	var target := tile.active_tile_card
	if target == null:
		return
	target.star_level = mini(target.star_level + 1, TileCard.MAX_STAR_LEVEL)
	tile.refresh_tile_card_visual_state()
	_show_text(tile, "%s!" % TileCard.star_text(target.star_level), Color(1.0, 0.85, 0.2, 1.0))


static func destroy_placed_at(
	source_tile: Hex,
	placed_card: TileCard,
	counts_as_break: bool = true
) -> void:
	if source_tile == null or source_tile.map == null or placed_card == null:
		return
	if counts_as_break:
		if CondimentManager.try_prevent_break(placed_card):
			_show_text(source_tile, "Warded", Color(0.45, 0.88, 0.58, 1.0))
			return
		source_tile.map.notify_card_broke(placed_card)
	if not counts_as_break:
		RunLedger.record_card_consumed(placed_card)
	source_tile.map.destroy_placed_tile_card(placed_card)


static func _show_text(tile: Hex, text: String, color: Color = Color.WHITE) -> void:
	if tile == null or tile.map == null:
		return
	var pos := tile.map.floating_text_position_for_hex(tile.coordinates)
	tile.map.create_floating_text(pos, text, color)


static func _show_failure(tile: Hex) -> void:
	_show_text(tile, "Failed", Color(1.0, 0.45, 0.45, 1.0))
