extends Node

## Run-long potion belt, targeting, and fuses applied to placed cards.

const BELT_SIZE := 3
const SHOP_STOCK := 3
const PACK_GRANT_COUNT := 3
const TWO_TURN_FUSE := 2
const HEX_MAP_GROUP := "hex_map_group"

## Belt slots. Null means empty.
var belt: Array[Potion] = []
## Slot being aimed at the map. -1 when idle.
var targeting_slot: int = -1
## Opening Round / Closing Round badges for this turn, keyed by Vector2i.
var _opening_coords: Array[Vector2i] = []
var _closing_coords: Array[Vector2i] = []
var _rewrite_use_count := 0
var _pack_use_count := 0
var _consuming := false


func _ready() -> void:
	belt.resize(BELT_SIZE)
	PotionCatalog.ensure_loaded()
	EventBus.turn_started.connect(_on_turn_started)


func reset_for_new_run() -> void:
	cancel_targeting()
	for i in BELT_SIZE:
		belt[i] = null
	_opening_coords.clear()
	_closing_coords.clear()
	_rewrite_use_count = 0
	_pack_use_count = 0
	_consuming = false
	EventBus.potion_belt_changed.emit()
	EventBus.potion_fuses_changed.emit()


func empty_slot_count() -> int:
	var count := 0
	for potion in belt:
		if potion == null:
			count += 1
	return count


func can_add() -> bool:
	return empty_slot_count() > 0


func add_potion(potion: Potion) -> bool:
	if potion == null:
		return false
	for i in BELT_SIZE:
		if belt[i] == null:
			belt[i] = potion
			EventBus.potion_belt_changed.emit()
			return true
	return false


func remove_slot(index: int) -> void:
	if index < 0 or index >= BELT_SIZE:
		return
	if targeting_slot == index:
		cancel_targeting()
	belt[index] = null
	EventBus.potion_belt_changed.emit()
	RunSaveManager.request_autosave()


func get_targeting_potion() -> Potion:
	if targeting_slot < 0 or targeting_slot >= BELT_SIZE:
		return null
	return belt[targeting_slot]


func can_drink_now() -> bool:
	if _consuming:
		return false
	if GameManager.is_processing_turn:
		return false
	return true


func can_use(potion: Potion) -> bool:
	if potion == null or not can_drink_now():
		return false
	if potion.effect_type == Potion.EffectType.REWRITE_OMEN:
		return ChallengeManager.get_next_challenge_round() != -1
	return true


func request_use_slot(index: int) -> void:
	if index < 0 or index >= BELT_SIZE:
		return
	var potion := belt[index]
	if potion == null:
		return
	if not can_use(potion):
		EventBus.potion_use_failed.emit(potion)
		return
	if potion.needs_tile_target():
		begin_targeting(index)
		return
	await _consume_instant(index)


## Headless playtests apply belt drinks immediately with no animation await.
func headless_use_slot(index: int, hex: Hex = null) -> bool:
	if index < 0 or index >= BELT_SIZE:
		return false
	var potion := belt[index]
	if potion == null or not can_use(potion):
		return false
	if potion.needs_tile_target():
		if hex == null or hex.active_tile_card == null or not _is_valid_tile_target(hex):
			return false
		belt[index] = null
		cancel_targeting()
		_apply_to_card(potion, hex)
	else:
		belt[index] = null
		_apply_instant(potion)
	EventBus.potion_belt_changed.emit()
	EventBus.potion_fuses_changed.emit()
	return true


func apply_to_hex(hex: Hex) -> void:
	var potion := get_targeting_potion()
	var slot := targeting_slot
	if potion == null or hex == null or hex.active_tile_card == null:
		return
	if not _is_valid_tile_target(hex):
		return
	await _consume_targeted(slot, potion, hex)


## Start map aiming after the player lifts a tile potion off the belt.
func begin_targeting(index: int) -> void:
	_begin_targeting(index)


## True when a dragged tile potion is released over a valid occupied hex.
func try_apply_to_hex_under_mouse() -> bool:
	if targeting_slot < 0 or _consuming:
		return false
	var hex := _hex_under_mouse()
	if hex == null or not _is_valid_tile_target(hex):
		return false
	apply_to_hex(hex)
	return true


func cancel_targeting() -> void:
	if targeting_slot < 0:
		return
	targeting_slot = -1
	_clear_map_target_highlights()
	EventBus.potion_targeting_changed.emit(-1)
	EventBus.tooltip_hover_refresh_requested.emit()


func is_targeting() -> bool:
	return targeting_slot >= 0


func try_prevent_break(card: TileCard) -> bool:
	if card == null:
		return false
	var fuse := _take_activation_fuse(card, Potion.EffectType.WARD)
	if fuse.is_empty():
		return false
	EventBus.potion_fuses_changed.emit()
	return true


func relay_product_if_needed(tile: Hex, product: TileCard.Product, amount: Variant) -> void:
	if tile == null or tile.map == null or tile.active_tile_card == null:
		return
	if not _card_has_fuse(tile.active_tile_card, Potion.EffectType.FORWARD_GIFT):
		return
	var next_index := _next_segment_index(tile)
	if next_index < 0:
		return
	match product:
		TileCard.Product.SCORE:
			tile.map.add_turn_score_for_segment(next_index, int(round(float(amount))))
			tile.map.mark_segment_received_relay(next_index)
			tile.map.flash_segment_highlight(next_index)
		TileCard.Product.MULTIPLIER:
			tile.map.add_turn_multiplier_for_segment(next_index, float(amount))
			tile.map.mark_segment_received_relay(next_index)
			tile.map.flash_segment_highlight(next_index)
		TileCard.Product.GOLD:
			tile.map.add_turn_gold_for_segment(next_index, int(round(float(amount))))
			tile.map.mark_segment_received_relay(next_index)
			tile.map.flash_segment_highlight(next_index)
		_:
			pass


func after_card_activated(tile: Hex, card: TileCard) -> void:
	if tile == null or card == null:
		return
	if _card_has_fuse(card, Potion.EffectType.MINT_SIP):
		tile.map.add_turn_gold_for_tile(tile, 1)
		var pos := tile.map.base_layer.map_to_local(tile.coordinates)
		tile.map.create_floating_text(pos, "+1", Color(1.0, 0.85, 0.2, 1.0))
	if _take_activation_fuse(card, Potion.EffectType.EMPOWER):
		pass
	if _take_activation_fuse(card, Potion.EffectType.BATON):
		_empower_next_producer(tile, card)
	if _take_activation_fuse(card, Potion.EffectType.ECHO):
		card.queue_tile_card_triggers(tile, [card])
	EventBus.potion_fuses_changed.emit()


func on_turn_resolved() -> void:
	_tick_two_turn_fuses()
	_opening_coords.clear()
	_closing_coords.clear()
	EventBus.potion_fuses_changed.emit()


func get_inspect_lines(card: TileCard, coords: Vector2i) -> Array[String]:
	var lines: Array[String] = []
	if card != null:
		for fuse in card.potion_fuses:
			var potion := PotionCatalog.get_by_id(str(fuse.get("potion_id", "")))
			if potion == null:
				continue
			lines.append(_fuse_inspect_text(potion, fuse))
	if coords in _opening_coords:
		var opening := PotionCatalog.get_by_id("opening_round")
		if opening != null:
			lines.append(opening.get_fuse_summary())
	if coords in _closing_coords:
		var closing := PotionCatalog.get_by_id("closing_round")
		if closing != null:
			lines.append(closing.get_fuse_summary())
	return lines


func get_badge_fuses(card: TileCard, coords: Vector2i) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	if card != null:
		for fuse in card.potion_fuses:
			badges.append(fuse)
	if coords in _opening_coords:
		badges.append({"potion_id": "opening_round", "remaining_turns": 1, "remaining_activations": 0})
	if coords in _closing_coords:
		badges.append({"potion_id": "closing_round", "remaining_turns": 1, "remaining_activations": 0})
	return badges


func capture_run_state() -> Dictionary:
	var slot_ids: Array = []
	for potion in belt:
		slot_ids.append(potion.id if potion != null else "")
	return {
		"belt": slot_ids,
		"opening_coords": _serialize_coords(_opening_coords),
		"closing_coords": _serialize_coords(_closing_coords),
		"rewrite_use_count": _rewrite_use_count,
		"pack_use_count": _pack_use_count,
	}


func apply_run_state(state: Dictionary) -> void:
	cancel_targeting()
	for i in BELT_SIZE:
		belt[i] = null
	var slot_ids: Array = state.get("belt", [])
	for i in mini(BELT_SIZE, slot_ids.size()):
		var potion_id := str(slot_ids[i])
		if potion_id.is_empty():
			continue
		belt[i] = PotionCatalog.get_by_id(potion_id)
	_opening_coords = _deserialize_coords(state.get("opening_coords", []))
	_closing_coords = _deserialize_coords(state.get("closing_coords", []))
	_rewrite_use_count = int(state.get("rewrite_use_count", 0))
	_pack_use_count = int(state.get("pack_use_count", 0))
	EventBus.potion_belt_changed.emit()
	EventBus.potion_fuses_changed.emit()


func _begin_targeting(index: int) -> void:
	targeting_slot = index
	_stamp_map_target_highlights()
	EventBus.potion_targeting_changed.emit(index)


func _consume_instant(index: int) -> void:
	var potion := belt[index]
	if potion == null:
		return
	_consuming = true
	EventBus.potion_consume_started.emit(index, potion)
	AudioManager.play_sfx(UISounds.CONSUME_POTION)
	await _await_consume_animation()
	if belt[index] != potion:
		_consuming = false
		return
	belt[index] = null
	_apply_instant(potion)
	EventBus.potion_belt_changed.emit()
	_consuming = false
	RunSaveManager.request_autosave()


func _consume_targeted(index: int, potion: Potion, hex: Hex) -> void:
	_consuming = true
	cancel_targeting()
	EventBus.potion_consume_started.emit(index, potion)
	AudioManager.play_sfx(UISounds.CONSUME_POTION)
	await _await_consume_animation()
	if belt[index] != potion:
		_consuming = false
		return
	belt[index] = null
	_apply_to_card(potion, hex)
	if hex.rune_ui != null:
		hex.rune_ui.play_potion_splash(potion.liquid_color)
	EventBus.potion_belt_changed.emit()
	EventBus.potion_fuses_changed.emit()
	_consuming = false
	RunSaveManager.request_autosave()


func _apply_instant(potion: Potion) -> void:
	match potion.effect_type:
		Potion.EffectType.GOLD_DROP:
			GoldManager.add(int(potion.effect_value))
			AudioManager.play_sfx(UISounds.GOLD_GAINED)
		Potion.EffectType.BORROWED_TIME:
			GameManager.add_bonus_turn()
		Potion.EffectType.REWRITE_OMEN:
			ChallengeManager.rewrite_upcoming_challenge(_rewrite_use_count)
			_rewrite_use_count += 1
		Potion.EffectType.FREE_REROLL:
			RerollManager.add_rerolls(1)
		Potion.EffectType.POTION_PACK:
			_grant_pack()
		Potion.EffectType.OPENING_ROUND:
			_empower_first_producers()
		Potion.EffectType.CLOSING_ROUND:
			_empower_last_producers()
		_:
			pass


func _apply_to_card(potion: Potion, hex: Hex) -> void:
	var card := hex.active_tile_card
	if card == null:
		return
	match potion.effect_type:
		Potion.EffectType.EMPOWER:
			card._empower()
			_add_fuse(card, potion, 0, 1)
		Potion.EffectType.ECHO, Potion.EffectType.WARD, Potion.EffectType.BATON:
			_add_fuse(card, potion, 0, 1)
		Potion.EffectType.FORWARD_GIFT, Potion.EffectType.MINT_SIP:
			_add_fuse(card, potion, TWO_TURN_FUSE, 0)
		_:
			pass
	hex.refresh_tile_card_visual_state()


func _grant_pack() -> void:
	_pack_use_count += 1
	var rng := RunRng.create_rng("potion_pack:r%d:n%d" % [GameManager.current_round, _pack_use_count])
	var drawn := PotionCatalog.draw_unique(PACK_GRANT_COUNT, rng, PotionCatalog.PACK_ID)
	for potion in drawn:
		if not add_potion(potion):
			break


func _empower_first_producers() -> void:
	_opening_coords.clear()
	for hex in _first_or_last_producers(true):
		hex.active_tile_card._empower()
		_opening_coords.append(hex.coordinates)
		hex.refresh_tile_card_visual_state()
		if hex.rune_ui != null:
			hex.rune_ui.play_potion_splash(Color(1.0, 0.72, 0.28, 1.0))
	EventBus.potion_fuses_changed.emit()


func _empower_last_producers() -> void:
	_closing_coords.clear()
	for hex in _first_or_last_producers(false):
		hex.active_tile_card._empower()
		_closing_coords.append(hex.coordinates)
		hex.refresh_tile_card_visual_state()
		if hex.rune_ui != null:
			hex.rune_ui.play_potion_splash(Color(0.86, 0.38, 0.18, 1.0))
	EventBus.potion_fuses_changed.emit()


func _first_or_last_producers(want_first: bool) -> Array[Hex]:
	var result: Array[Hex] = []
	var tile_map := _tile_map()
	if tile_map == null:
		return result
	for segment_index in tile_map.get_segment_count():
		var chosen: Hex = null
		for hex in tile_map.get_hexes_in_segment(segment_index):
			var card := hex.active_tile_card
			if card == null or card.type != TileCard.TileCardType.PRODUCER:
				continue
			if not tile_map.is_tile_card_triggerable(hex):
				continue
			if want_first:
				chosen = hex
				break
			chosen = hex
		if chosen != null:
			result.append(chosen)
	return result


func _empower_next_producer(tile: Hex, source: TileCard) -> void:
	var tile_map := tile.map
	var seen_source := false
	for hex in tile_map.get_hexes_in_trigger_order():
		if hex.active_tile_card == source:
			seen_source = true
			continue
		if not seen_source:
			continue
		var card := hex.active_tile_card
		if card == null or card.type != TileCard.TileCardType.PRODUCER:
			continue
		if not tile_map.is_tile_card_triggerable(hex):
			continue
		card._empower()
		hex.refresh_tile_card_visual_state()
		return


func _add_fuse(card: TileCard, potion: Potion, remaining_turns: int, remaining_activations: int) -> void:
	card.potion_fuses.append({
		"potion_id": potion.id,
		"effect_type": potion.effect_type,
		"remaining_turns": remaining_turns,
		"remaining_activations": remaining_activations,
	})


func _card_has_fuse(card: TileCard, effect_type: Potion.EffectType) -> bool:
	for fuse in card.potion_fuses:
		if int(fuse.get("effect_type", -1)) == effect_type:
			return true
	return false


func _take_activation_fuse(card: TileCard, effect_type: Potion.EffectType) -> Dictionary:
	for i in card.potion_fuses.size():
		var fuse: Dictionary = card.potion_fuses[i]
		if int(fuse.get("effect_type", -1)) != effect_type:
			continue
		if int(fuse.get("remaining_activations", 0)) <= 0:
			continue
		card.potion_fuses.remove_at(i)
		return fuse
	return {}


func _tick_two_turn_fuses() -> void:
	var tile_map := _tile_map()
	if tile_map == null:
		return
	for hex in tile_map.get_all_hexes_with_runes():
		var card := hex.active_tile_card
		if card == null:
			continue
		var kept: Array[Dictionary] = []
		for fuse in card.potion_fuses:
			var turns := int(fuse.get("remaining_turns", 0))
			if turns <= 0:
				kept.append(fuse)
				continue
			turns -= 1
			if turns <= 0:
				continue
			fuse["remaining_turns"] = turns
			kept.append(fuse)
		card.potion_fuses = kept
		hex.refresh_tile_card_visual_state()


func _is_valid_tile_target(hex: Hex) -> bool:
	if hex == null or hex.active_tile_card == null:
		return false
	var tile_map := hex.map
	if tile_map == null:
		return false
	return tile_map.is_tile_interactable(hex.coordinates)


func _stamp_map_target_highlights() -> void:
	var tile_map := _tile_map()
	if tile_map == null:
		return
	var coords: Array[Vector2i] = []
	for hex in tile_map.get_all_hexes_with_runes():
		if _is_valid_tile_target(hex):
			coords.append(hex.coordinates)
	tile_map.set_potion_target_highlights(coords)


func _clear_map_target_highlights() -> void:
	var tile_map := _tile_map()
	if tile_map != null:
		tile_map.clear_potion_target_highlights()


func _next_segment_index(tile: Hex) -> int:
	var next_index := tile.map.get_segment_index(tile.coordinates) + 1
	if next_index < 0 or next_index >= tile.map.get_segment_count():
		return -1
	return next_index


func _fuse_inspect_text(potion: Potion, fuse: Dictionary) -> String:
	var turns := int(fuse.get("remaining_turns", 0))
	if turns > 0:
		var turn_word := "turn" if turns == 1 else "turns"
		return "%s · %d %s left" % [potion.display_name, turns, turn_word]
	return potion.get_fuse_summary()


func _serialize_coords(coords: Array[Vector2i]) -> Array:
	var packed: Array = []
	for cell in coords:
		packed.append([cell.x, cell.y])
	return packed


func _deserialize_coords(raw: Variant) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if raw is not Array:
		return coords
	for entry in raw:
		if entry is Array and entry.size() >= 2:
			coords.append(Vector2i(int(entry[0]), int(entry[1])))
	return coords


func _tile_map() -> HexTileMap:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(HEX_MAP_GROUP) as HexTileMap


func _await_consume_animation() -> void:
	if GameManager.skip_presentation:
		return
	var state := {"done": false}
	var on_done := func() -> void:
		state.done = true
	EventBus.potion_consume_animation_finished.connect(on_done)
	var timer := get_tree().create_timer(0.85)
	timer.timeout.connect(func() -> void: state.done = true)
	while not state.done and is_inside_tree():
		await get_tree().process_frame
	if EventBus.potion_consume_animation_finished.is_connected(on_done):
		EventBus.potion_consume_animation_finished.disconnect(on_done)


func _hex_under_mouse() -> Hex:
	# Resolve the hex under the cursor so a belt drop can land on a tile.
	var tile_map := _tile_map()
	if tile_map == null:
		return null
	var coords := tile_map.base_layer.local_to_map(
		tile_map.to_local(tile_map.get_global_mouse_position())
	)
	if not tile_map.is_in_map(coords):
		return null
	return tile_map.map_data.get(coords) as Hex


func _unhandled_input(event: InputEvent) -> void:
	if targeting_slot < 0 or _consuming:
		return
	# Esc still aborts a drag if the belt did not consume the event first.
	if event.is_action_pressed("ui_cancel"):
		cancel_targeting()
		get_viewport().set_input_as_handled()


func _on_turn_started() -> void:
	if targeting_slot >= 0 and GameManager.is_processing_turn:
		cancel_targeting()
