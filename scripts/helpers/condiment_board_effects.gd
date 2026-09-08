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


static func upgrade_plate(tile: Hex, rng: RandomNumberGenerator) -> bool:
	var target := tile.active_tile_card
	if target == null:
		return false
	if target.rarity >= TileCard.TileCardRarity.RARE:
		_show_failure(tile)
		return false

	var higher_rarity := (target.rarity + 1) as TileCard.TileCardRarity
	var replacement := pick_random_placeable(higher_rarity, "", rng)
	if replacement == null:
		_show_failure(tile)
		return false

	replace_placed_at(tile, replacement)
	_show_text(tile, "Upgraded!")
	return true


static func reroll_plate(tile: Hex, rng: RandomNumberGenerator) -> bool:
	var target := tile.active_tile_card
	if target == null:
		return false

	var replacement := pick_random_placeable(target.rarity, target.id, rng)
	if replacement == null:
		_show_failure(tile)
		return false

	replace_placed_at(tile, replacement)
	_show_text(tile, "Transformed!")
	return true


static func send_back(tile: Hex) -> bool:
	if tile.active_tile_card == null:
		return false

	copy_placed_to_hand(tile.active_tile_card)
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
	hex_a.map.swap_placed_tile_cards(hex_a, hex_b)
	_show_text(hex_a, "Swapped")
	_show_text(hex_b, "Swapped")
	return true


static func copy_placed_to_hand(source_card: TileCard) -> void:
	var hand_copy: TileCard = source_card.duplicate(true)
	hand_copy.activation_count = 0
	hand_copy.is_empowered = false
	hand_copy.is_active = true
	EventBus.tile_card_selected.emit(hand_copy)


static func pick_random_placeable(
	filter_rarity: Variant = null,
	exclude_id: String = "",
	rng: RandomNumberGenerator = null
) -> TileCard:
	var candidates: Array[TileCard] = []
	for template: TileCard in GameManager.tile_cards_pool:
		if filter_rarity != null and template.rarity != filter_rarity:
			continue
		if not exclude_id.is_empty() and template.id == exclude_id:
			continue
		if not template.is_legal_for_layout(GameManager.selected_character):
			continue
		candidates.append(template)

	if candidates.is_empty():
		return null

	if rng == null:
		return RunRng.pick_random_tile_card(candidates)

	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return a.id < b.id
	)
	return RunRng.pick_random_with(rng, sorted) as TileCard


static func replace_placed_at(tile: Hex, replacement_template: TileCard) -> void:
	if tile.active_tile_card == null or replacement_template == null:
		return

	var old_card := tile.active_tile_card
	var retained_bonus := old_card.bonus_production_amount

	destroy_placed_at(tile, old_card, false)
	tile.place_tile_card(replacement_template)

	var new_card := tile.active_tile_card
	if new_card == null:
		return

	new_card.bonus_production_amount = retained_bonus


static func destroy_placed_at(
	source_tile: Hex,
	placed_card: TileCard,
	counts_as_break: bool = true
) -> void:
	if source_tile == null or source_tile.map == null or placed_card == null:
		return
	var broken_hex := source_tile.map.get_hex_for_tile_card(placed_card)
	if broken_hex == null:
		broken_hex = source_tile
	if counts_as_break:
		if CondimentManager.try_prevent_break(placed_card):
			_show_text(source_tile, "Warded", Color(0.45, 0.88, 0.58, 1.0))
			return
		if GameManager.passive_runtime.try_prevent_break(source_tile, placed_card):
			_show_text(source_tile, "Saved", Color(0.55, 0.85, 0.7, 1.0))
			return
		var segment_index := source_tile.map.get_segment_index(broken_hex.coordinates)
		var on_one_tile := segment_index == -1 or source_tile.map.get_segment_size(segment_index) == 1
		MetaProgressionManager.record_card_broken(on_one_tile)
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
