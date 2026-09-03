extends Node


# Manages round events on rounds 3, 6, and 9. Three unique events are picked at run start.

enum Type {
	BLACKOUT,
	RUSH_HOUR,
	DEALT_HAND,
	FADING_SECTOR,
	DRY_WIRE,
	NULL_CHARGE,
	LOCAL_CURRENT,
	AUSTERITY,
	SEALED_HEXES,
	JAMMED_BELT,
	RAISED_STAKES,
}

const EVENT_ROUNDS := [3, 6, 9]
const ANY_EVENT_ROUND := [3, 6, 9]
const LATE_EVENT_ROUNDS := [6, 9]
const FINAL_EVENT_ROUND := [9]
const BLACKOUT_COUNT := 5
const SEALED_HEX_COUNT := 3
const RAISED_STAKES_SCORE_SCALE := 1.25

const ALL_EVENTS: Array[Type] = [
	Type.BLACKOUT,
	Type.RUSH_HOUR,
	Type.DEALT_HAND,
	Type.FADING_SECTOR,
	Type.DRY_WIRE,
	Type.NULL_CHARGE,
	Type.LOCAL_CURRENT,
	Type.AUSTERITY,
	Type.SEALED_HEXES,
	Type.JAMMED_BELT,
	Type.RAISED_STAKES,
]

const EVENT_INFO := {
	Type.BLACKOUT: {
		"name": "Blackout",
		"description": "Every hour, 5 random seated cards on the pass are disabled.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.RUSH_HOUR: {
		"name": "Rush Hour",
		"description": "You have 1 less hour to complete the day.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.DEALT_HAND: {
		"name": "Dealt Hand",
		"description": "At the end of each hour, you are dealt a random card instead of choosing one.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.FADING_SECTOR: {
		"name": "Fading Course",
		"description": "Every hour, a random course has its Ingredient output halved.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.DRY_WIRE: {
		"name": "Dry Wire",
		"description": "Extra activations and queued Again effects do not fire.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.NULL_CHARGE: {
		"name": "Null Charge",
		"description": "Double still consumes, but it does not double output.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.LOCAL_CURRENT: {
		"name": "Local Current",
		"description": "Products cannot be Passed to another course.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.AUSTERITY: {
		"name": "Austerity",
		"description": "You cannot gain gold this day.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.SEALED_HEXES: {
		"name": "Sealed Spots",
		"description": "Three empty spots cannot be played on this day.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.JAMMED_BELT: {
		"name": "Jammed Belt",
		"description": "Condiments cannot be used this day.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.RAISED_STAKES: {
		"name": "Raised Stakes",
		"description": "The day Rating target is 25% higher.",
		"rounds": FINAL_EVENT_ROUND,
	},
}

## One event per entry in EVENT_ROUNDS, chosen at run start.
var scheduled_events: Array[Type] = []
## Active event for the current round, -1 when no event is running.
var active_event: int = -1

## Index of the segment whose producer output is halved, -1 when not in fading sector.
var _halved_segment_index := -1
## Empty tiles locked by Sealed Hexes for the current round.
var _sealed_coords: Array[Vector2i] = []

## Saved is_active values so player toggles are restored after each turn's blackout.
var _disabled_prior_states: Dictionary = {}
var _tile_map: HexTileMap = null


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


# Pick three unique events that are legal for rounds 3, 6, and 9.
func init_run() -> void:
	scheduled_events.clear()
	active_event = -1
	_halved_segment_index = -1
	_clear_sealed_hexes()
	_disabled_prior_states.clear()
	_clear_fading_sector_visuals()

	var used: Array[Type] = []
	var rng := RunRng.create_rng("events")
	for event_round in EVENT_ROUNDS:
		var available := _unused_legal_types(event_round, used)
		if available.is_empty():
			push_error("EventManager: no legal event left for round %d." % event_round)
			break
		RunRng.shuffle_with(rng, available)
		var picked: Type = available[0]
		scheduled_events.append(picked)
		used.append(picked)

	EventBus.event_schedule_changed.emit()


func on_round_advanced(new_round: int) -> void:
	_clear_fading_sector_visuals()
	_clear_sealed_hexes()
	active_event = get_event_for_round(new_round)
	_restore_event_disabled_runes()

	if active_event == Type.SEALED_HEXES:
		_pick_sealed_hexes()

	# Rush Hour's turn cap has to apply now. RoundFlow decides when the reveal plays.
	if active_event == -1:
		EventBus.event_banner_hidden.emit()

	EventBus.event_changed.emit()


## Plays the event reveal. Returns whether a banner actually started, so the caller
## knows whether to wait for event_reveal_finished.
func play_reveal() -> bool:
	if active_event == -1:
		return false

	AudioManager.play_sfx(UISounds.EVENT_START)
	EventBus.event_banner_shown.emit(get_active_event_name(), false)
	return true


func is_completing_final_event_round() -> bool:
	return (
		GameManager.current_round == EVENT_ROUNDS[-1]
		and get_event_for_round(GameManager.current_round) != -1
	)


func get_event_for_round(event_round: int) -> int:
	var round_index := EVENT_ROUNDS.find(event_round)
	if round_index == -1:
		return -1
	# Left panel can query before main.gd calls init_run() at run start.
	if round_index >= scheduled_events.size():
		return -1
	return scheduled_events[round_index]


func get_next_event_round() -> int:
	for event_round in EVENT_ROUNDS:
		if event_round > GameManager.current_round:
			return event_round
	return -1


func get_next_event_type() -> int:
	var next_round := get_next_event_round()
	if next_round == -1:
		return -1
	return get_event_for_round(next_round)


func is_legal_for_round(event_type: int, event_round: int) -> bool:
	if not ALL_EVENTS.has(event_type):
		return false
	var allowed: Array = EVENT_INFO[event_type].get("rounds", EVENT_ROUNDS)
	return allowed.has(event_round)


func get_allowed_rounds(event_type: int) -> Array:
	if not ALL_EVENTS.has(event_type):
		return []
	return EVENT_INFO[event_type].get("rounds", EVENT_ROUNDS)


func get_allowed_rounds_label(event_type: int) -> String:
	var allowed: Array = get_allowed_rounds(event_type)
	if allowed == ANY_EVENT_ROUND or allowed == EVENT_ROUNDS:
		return "Any event round"
	if allowed.size() == 1:
		return "Round %d only" % int(allowed[0])
	if allowed.size() == 2:
		return "Rounds %d and %d" % [int(allowed[0]), int(allowed[1])]
	var parts: PackedStringArray = []
	for allowed_round in allowed:
		parts.append(str(int(allowed_round)))
	return "Rounds %s" % ", ".join(parts)


## True when Rewrite Omen has an unused type that is legal for the upcoming event round.
func can_rewrite_upcoming() -> bool:
	var next_round := get_next_event_round()
	if next_round == -1:
		return false
	return not _unused_legal_types(next_round, scheduled_events).is_empty()


## Replaces the next unstarted event with a type not already on the calendar, legal for that round.
func rewrite_upcoming_event(use_index: int) -> bool:
	var next_round := get_next_event_round()
	if next_round == -1:
		return false
	var slot := EVENT_ROUNDS.find(next_round)
	if slot < 0 or slot >= scheduled_events.size():
		return false

	var unused := _unused_legal_types(next_round, scheduled_events)
	if unused.is_empty():
		return false

	var rng := RunRng.create_rng("condiment:rewrite_omen:r%d:n%d" % [
		GameManager.current_round,
		use_index,
	])
	RunRng.shuffle_with(rng, unused)
	scheduled_events[slot] = unused[0] as Type
	EventBus.event_schedule_changed.emit()
	return true


func get_event_name(event_type: int) -> String:
	if event_type == -1:
		return ""
	return EVENT_INFO[event_type]["name"]


func get_event_description(event_type: int) -> String:
	if event_type == -1:
		return ""
	return EVENT_INFO[event_type]["description"]


func get_active_event_name() -> String:
	return get_event_name(active_event)


func get_max_turns_per_round() -> int:
	if active_event == Type.RUSH_HOUR:
		return GameManager.MAX_TURNS_PER_ROUND - 1
	return GameManager.MAX_TURNS_PER_ROUND


## Pack size for the current offer.
func get_runes_pack_size(is_round_reward: Variant = null) -> int:
	var reward := bool(is_round_reward) if is_round_reward != null else RoundFlow.is_transitioning()
	if _get_governing_event(reward) == Type.DEALT_HAND:
		return 1
	return GameManager.RUNES_PACK_SIZE


## Dealt Hand skips the draft overlay and grants the lone card immediately.
func should_auto_grant_rune(is_round_reward: bool = false) -> bool:
	return _get_governing_event(is_round_reward) == Type.DEALT_HAND


## Draws one card from the same stream as the draft panel and adds it to the hand.
func grant_auto_rune(is_round_reward: bool, fail_remaining_turns: int = -1) -> bool:
	if not should_auto_grant_rune(is_round_reward):
		return false
	if GameManager.tile_cards_pool.is_empty():
		push_error("EventManager: cannot auto-grant rune, pool is empty.")
		return false

	var round_number := GameManager.current_round
	if is_round_reward and RoundFlow.is_transitioning():
		round_number = RoundFlow.get_transition_rune_pick_round()
	var remaining_turns := fail_remaining_turns if fail_remaining_turns >= 0 else GameManager.remaining_turns
	var stream_name := RunRng.build_rune_offer_stream_name(
		round_number,
		remaining_turns,
		is_round_reward,
		0
	)
	var loot_rng := RunRng.create_rng(stream_name)
	var pack := CardLoot.draw_runes(1, GameManager.tile_cards_pool, true, loot_rng)
	if pack.is_empty():
		return false

	EventBus.tile_card_selected.emit(pack[0])
	return true


func _get_governing_event(is_round_reward: bool) -> int:
	var governing_event := active_event
	if is_round_reward and RoundFlow.is_transitioning():
		governing_event = RoundFlow.get_outgoing_event()
	return governing_event


func get_producer_output_multiplier(tile: Hex) -> float:
	if active_event != Type.FADING_SECTOR or _halved_segment_index < 0:
		return 1.0
	if tile.active_tile_card == null or not TileCard.is_producer_type(tile.active_tile_card.type):
		return 1.0

	var tile_map := _get_tile_map()
	if tile_map == null:
		return 1.0
	if tile_map.get_segment_index(tile.coordinates) != _halved_segment_index:
		return 1.0
	return 0.5


func apply_score_modifier(base_score: int) -> int:
	if active_event != Type.RAISED_STAKES:
		return base_score
	return int(round(float(base_score) * RAISED_STAKES_SCORE_SCALE))


## Dry Wire. Trigger-order slots still fire. Queued extras do not.
func are_retriggers_blocked() -> bool:
	return active_event == Type.DRY_WIRE


## Null Charge. Empower is still consumed so it cannot leak into the next round.
func are_empowers_blocked() -> bool:
	return active_event == Type.NULL_CHARGE


## Local Current. Forward Gift and card relays both check this.
func are_relays_blocked() -> bool:
	return active_event == Type.LOCAL_CURRENT


## Austerity. Spending gold is still allowed.
func can_gain_gold() -> bool:
	return active_event != Type.AUSTERITY


## Jammed Belt. Fuses already on tiles keep running.
func are_condiments_blocked() -> bool:
	return active_event == Type.JAMMED_BELT


## Sealed Hexes. Empty tiles locked for the rest of the round.
func is_hex_sealed(coords: Vector2i) -> bool:
	return _sealed_coords.has(coords)


func _on_turn_started() -> void:
	if active_event == Type.BLACKOUT:
		_clear_fading_sector_visuals()
		_apply_blackout()
	elif active_event == Type.FADING_SECTOR:
		_restore_event_disabled_runes()
		_pick_halved_segment()
	else:
		_restore_event_disabled_runes()
		_clear_fading_sector_visuals()


func _apply_blackout() -> void:
	_restore_event_disabled_runes()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	var hexes_with_runes := tile_map.get_all_hexes_with_runes()
	hexes_with_runes.sort_custom(func(a: Hex, b: Hex) -> bool:
		if a.coordinates.x != b.coordinates.x:
			return a.coordinates.x < b.coordinates.x
		return a.coordinates.y < b.coordinates.y
	)
	var rng := RunRng.create_rng("event:blackout:r%d:s%d" % [
		GameManager.current_round,
		GameManager.turn_stamp,
	])
	RunRng.shuffle_with(rng, hexes_with_runes)

	for i in mini(BLACKOUT_COUNT, hexes_with_runes.size()):
		var hex := hexes_with_runes[i]
		var rune := hex.active_tile_card
		if rune == null:
			continue
		_disabled_prior_states[rune] = rune.is_active
		rune.is_active = false
		hex.refresh_tile_card_visual_state()


func _restore_event_disabled_runes() -> void:
	var tile_map := _get_tile_map()
	for rune: TileCard in _disabled_prior_states:
		if is_instance_valid(rune):
			rune.is_active = _disabled_prior_states[rune]
			if tile_map != null:
				var hex := tile_map.get_hex_for_tile_card(rune)
				if hex != null:
					hex.refresh_tile_card_visual_state()
	_disabled_prior_states.clear()


func _pick_halved_segment() -> void:
	_clear_fading_sector_visuals()

	var tile_map := _get_tile_map()
	if tile_map == null:
		_halved_segment_index = -1
		return

	var segment_count := tile_map.get_segment_count()
	if segment_count <= 0:
		_halved_segment_index = -1
		return

	_halved_segment_index = RunRng.create_rng("event:fading_sector:r%d:s%d" % [
		GameManager.current_round,
		GameManager.turn_stamp,
	]).randi() % segment_count
	_apply_fading_sector_visuals()
	EventBus.event_changed.emit()


func _apply_fading_sector_visuals() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null or _halved_segment_index < 0:
		return

	tile_map.highlight_event_segment(_halved_segment_index)
	for hex: Hex in tile_map.get_hexes_in_segment(_halved_segment_index):
		if hex.active_tile_card == null:
			continue
		if not TileCard.is_producer_type(hex.active_tile_card.type):
			continue
		hex.set_tile_card_event_modulate(Hex.RUNE_FADED_SECTOR_MODULATE)


func _clear_fading_sector_visuals() -> void:
	_halved_segment_index = -1
	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	tile_map.clear_event_segment_highlight()
	for hex: Hex in tile_map.map_data.values():
		hex.clear_tile_card_event_modulate()


func _pick_sealed_hexes() -> void:
	_clear_sealed_hexes()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	var candidates: Array[Vector2i] = []
	for coords: Vector2i in tile_map.map_data:
		var hex: Hex = tile_map.map_data[coords]
		if hex.is_disabled_by_difficulty:
			continue
		if hex.active_tile_card != null:
			continue
		candidates.append(coords)

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	var rng := RunRng.create_rng("event:sealed_hexes:r%d" % GameManager.current_round)
	RunRng.shuffle_with(rng, candidates)

	for i in mini(SEALED_HEX_COUNT, candidates.size()):
		_sealed_coords.append(candidates[i])
	_apply_sealed_overlay()


func _clear_sealed_hexes() -> void:
	_sealed_coords.clear()
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_event_sealed_overlay()


func _apply_sealed_overlay() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	tile_map.set_event_sealed_overlay(_sealed_coords)


func _unused_legal_types(event_round: int, used: Array) -> Array:
	var available: Array = []
	for event_type in ALL_EVENTS:
		if used.has(event_type):
			continue
		if not is_legal_for_round(event_type, event_round):
			continue
		available.append(event_type)
	return available


func _get_tile_map() -> HexTileMap:
	if _tile_map != null and is_instance_valid(_tile_map):
		return _tile_map

	for node in get_tree().get_nodes_in_group("hex_map_group"):
		_tile_map = node as HexTileMap
		if _tile_map != null:
			return _tile_map
	return null


func _refresh_required_score() -> void:
	var base_score := ScoreProgression.get_required_score(GameManager.current_round)
	GameManager.required_score = apply_score_modifier(base_score)
	EventBus.required_score_changed.emit()


#region Debug

## Forces an event on the current round and applies its immediate effects.
func debug_activate_event(event_type: int) -> void:
	if not ALL_EVENTS.has(event_type):
		push_warning("EventManager: invalid debug event type %d." % event_type)
		return

	var previous_event := active_event
	_restore_event_disabled_runes()
	_clear_fading_sector_visuals()
	_clear_sealed_hexes()
	active_event = event_type
	_apply_rush_hour_turn_cap(previous_event)
	_refresh_required_score()

	match active_event:
		Type.BLACKOUT:
			_apply_blackout()
		Type.FADING_SECTOR:
			_pick_halved_segment()
		Type.SEALED_HEXES:
			_pick_sealed_hexes()

	EventBus.event_changed.emit()
	play_reveal()


## Clears any sandbox-forced event and restores normal map visuals.
func debug_clear_event() -> void:
	var previous_event := active_event
	if previous_event == -1:
		return

	_restore_event_disabled_runes()
	_clear_fading_sector_visuals()
	_clear_sealed_hexes()
	active_event = -1
	_apply_rush_hour_turn_cap(previous_event)
	_refresh_required_score()
	EventBus.event_banner_hidden.emit()
	EventBus.event_changed.emit()


func _apply_rush_hour_turn_cap(previous_event: int) -> void:
	var rush_hour_changed := (
		previous_event == Type.RUSH_HOUR
		or active_event == Type.RUSH_HOUR
	)
	if not rush_hour_changed:
		return

	var max_turns := get_max_turns_per_round()
	if GameManager.remaining_turns > max_turns:
		GameManager.remaining_turns = max_turns
	EventBus.turn_changed.emit()

#endregion

func capture_run_state() -> Dictionary:
	var sealed: Array = []
	for coords in _sealed_coords:
		sealed.append([coords.x, coords.y])
	return {
		"scheduled_events": scheduled_events.duplicate(),
		"active_event": active_event,
		"halved_segment_index": _halved_segment_index,
		"sealed_coords": sealed,
	}


func apply_run_state(state: Dictionary) -> void:
	scheduled_events.clear()
	for event_type in state.get("scheduled_events", []):
		var saved := int(event_type)
		if ALL_EVENTS.has(saved):
			scheduled_events.append(saved)

	var saved_active := int(state.get("active_event", -1))
	active_event = saved_active if ALL_EVENTS.has(saved_active) else -1
	_halved_segment_index = int(state.get("halved_segment_index", -1))
	_sealed_coords.clear()
	for coords_data: Variant in state.get("sealed_coords", []):
		if coords_data is not Array or coords_data.size() < 2:
			continue
		_sealed_coords.append(Vector2i(int(coords_data[0]), int(coords_data[1])))
	_disabled_prior_states.clear()
	_tile_map = null


func restore_banner_after_load() -> void:
	# A queued reveal stays queued so the load does not spoil it before the merchant closes.
	if active_event == -1 or RoundFlow.has_armed_event_reveal():
		EventBus.event_banner_hidden.emit()
		return

	EventBus.event_banner_shown.emit(get_active_event_name(), true)


func refresh_event_visuals() -> void:
	if active_event == Type.FADING_SECTOR and _halved_segment_index >= 0:
		_apply_fading_sector_visuals()
	else:
		# Keep a saved halved index if Fading Sector is active but the overlay was not ready yet.
		var saved_halved := _halved_segment_index
		_clear_fading_sector_visuals()
		if active_event == Type.FADING_SECTOR:
			_halved_segment_index = saved_halved

	if active_event == Type.SEALED_HEXES and not _sealed_coords.is_empty():
		_apply_sealed_overlay()
	else:
		var tile_map := _get_tile_map()
		if tile_map != null:
			tile_map.clear_event_sealed_overlay()
