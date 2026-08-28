extends Node


# Manages round challenges on rounds 3, 6, and 9. Three challenges are picked at run start.

enum Type {
	BLACKOUT,
	RUSH_HOUR,
	SOLO_PACT,
	TAXATION,
	FADING_SECTOR,
}

const CHALLENGE_ROUNDS := [3, 6, 9]

const ALL_CHALLENGES: Array[Type] = [
	Type.BLACKOUT,
	Type.RUSH_HOUR,
	Type.SOLO_PACT,
	Type.TAXATION,
	Type.FADING_SECTOR,
]

const CHALLENGE_INFO := {
	Type.BLACKOUT: {
		"name": "Blackout",
		"description": "Every turn, 5 random cards on the map are disabled.",
	},
	Type.RUSH_HOUR: {
		"name": "Rush Hour",
		"description": "You have 1 less turn to complete the round.",
	},
	Type.SOLO_PACT: {
		"name": "Solo Pact",
		"description": "Only 1 card choice at the start of every turn.",
	},
	Type.TAXATION: {
		"name": "Taxation",
		"description": "Lose 1 gold on every support card trigger.",
	},
	Type.FADING_SECTOR: {
		"name": "Fading Sector",
		"description": "Every turn, a random segment has its producer output halved.",
	},
}

## One challenge per entry in CHALLENGE_ROUNDS, chosen at run start.
var scheduled_challenges: Array[Type] = []
## Active challenge for the current round, -1 when no challenge is running.
var active_challenge: int = -1

## Index of the segment whose producer output is halved, -1 when not in fading sector challenge.
var _halved_segment_index := -1

## Saved is_active values so player toggles are restored after each turn's blackout.
var _disabled_prior_states: Dictionary = {}
var _tile_map: HexTileMap = null


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.tile_card_activated.connect(_on_tile_card_activated)


# Pick three unique challenges for rounds 3, 6, and 9 at the start of a run.
func init_run() -> void:
	scheduled_challenges.clear()
	active_challenge = -1
	_halved_segment_index = -1
	_disabled_prior_states.clear()
	_clear_fading_sector_visuals()

	var pool := ALL_CHALLENGES.duplicate()
	RunRng.shuffle_with(RunRng.create_rng("challenges"), pool)
	for i in CHALLENGE_ROUNDS.size():
		scheduled_challenges.append(pool[i])

	EventBus.challenge_schedule_changed.emit()


func on_round_advanced(new_round: int) -> void:
	_clear_fading_sector_visuals()
	active_challenge = get_challenge_for_round(new_round)
	_restore_challenge_disabled_runes()

	# Rush Hour's turn cap has to apply now. RoundFlow decides when the reveal plays.
	if active_challenge == -1:
		EventBus.challenge_banner_hidden.emit()

	EventBus.challenge_changed.emit()


## Plays the challenge reveal. Returns whether a banner actually started, so the caller
## knows whether to wait for challenge_reveal_finished.
func play_reveal() -> bool:
	if active_challenge == -1:
		return false

	AudioManager.play_sfx(UISounds.CHALLENGE_START)
	EventBus.challenge_banner_shown.emit(get_active_challenge_name(), false)
	return true


func is_completing_final_challenge_round() -> bool:
	return (
		GameManager.current_round == CHALLENGE_ROUNDS[-1]
		and get_challenge_for_round(GameManager.current_round) != -1
	)


func get_challenge_for_round(round: int) -> int:
	var round_index := CHALLENGE_ROUNDS.find(round)
	if round_index == -1:
		return -1
	# Left panel can query before main.gd calls init_run() at run start.
	if round_index >= scheduled_challenges.size():
		return -1
	return scheduled_challenges[round_index]


func get_next_challenge_round() -> int:
	for round in CHALLENGE_ROUNDS:
		if round > GameManager.current_round:
			return round
	return -1


func get_next_challenge_type() -> int:
	var next_round := get_next_challenge_round()
	if next_round == -1:
		return -1
	return get_challenge_for_round(next_round)


func get_challenge_name(challenge_type: int) -> String:
	if challenge_type == -1:
		return ""
	return CHALLENGE_INFO[challenge_type]["name"]


func get_challenge_description(challenge_type: int) -> String:
	if challenge_type == -1:
		return ""
	return CHALLENGE_INFO[challenge_type]["description"]


func get_active_challenge_name() -> String:
	return get_challenge_name(active_challenge)


func get_max_turns_per_round() -> int:
	if active_challenge == Type.RUSH_HOUR:
		return GameManager.MAX_TURNS_PER_ROUND - 1
	return GameManager.MAX_TURNS_PER_ROUND


func get_runes_pack_size() -> int:
	# The post-round reward pick belongs to the round that just ended, so a challenge starting
	# on the round being entered must not shrink it. In-round picks use the live challenge.
	var governing_challenge := active_challenge
	if RoundFlow.is_transitioning():
		governing_challenge = RoundFlow.get_outgoing_challenge()

	if governing_challenge == Type.SOLO_PACT:
		return 1
	return GameManager.RUNES_PACK_SIZE


func get_producer_output_multiplier(tile: Hex) -> float:
	if active_challenge != Type.FADING_SECTOR or _halved_segment_index < 0:
		return 1.0
	if tile.active_tile_card == null or tile.active_tile_card.type != TileCard.TileCardType.PRODUCER:
		return 1.0

	var tile_map := _get_tile_map()
	if tile_map == null:
		return 1.0
	if tile_map.get_segment_index(tile.coordinates) != _halved_segment_index:
		return 1.0
	return 0.5


func _on_turn_started() -> void:
	if active_challenge == Type.BLACKOUT:
		_clear_fading_sector_visuals()
		_apply_blackout()
	elif active_challenge == Type.FADING_SECTOR:
		_restore_challenge_disabled_runes()
		_pick_halved_segment()
	else:
		_restore_challenge_disabled_runes()
		_clear_fading_sector_visuals()


func _on_tile_card_activated(rune: TileCard) -> void:
	if active_challenge != Type.TAXATION:
		return
	if rune.type != TileCard.TileCardType.SUPPORT:
		return
	if GoldManager.amount <= 0:
		return

	GoldManager.remove(1)
	var tile_map := _get_tile_map()
	if tile_map != null:
		var hex := tile_map.get_hex_for_tile_card(rune)
		if hex != null:
			var tile_pos := tile_map.base_layer.map_to_local(hex.coordinates)
			tile_map.create_floating_text(tile_pos, "-1 Gold", Color.GOLD)


func _apply_blackout() -> void:
	_restore_challenge_disabled_runes()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	var hexes_with_runes := tile_map.get_all_hexes_with_runes()
	hexes_with_runes.sort_custom(func(a: Hex, b: Hex) -> bool:
		if a.coordinates.x != b.coordinates.x:
			return a.coordinates.x < b.coordinates.x
		return a.coordinates.y < b.coordinates.y
	)
	var rng := RunRng.create_rng("challenge:blackout:r%d:s%d" % [
		GameManager.current_round,
		GameManager.turn_stamp,
	])
	RunRng.shuffle_with(rng, hexes_with_runes)

	for i in mini(5, hexes_with_runes.size()):
		var hex := hexes_with_runes[i]
		var rune := hex.active_tile_card
		if rune == null:
			continue
		_disabled_prior_states[rune] = rune.is_active
		rune.is_active = false
		hex.refresh_tile_card_visual_state()


func _restore_challenge_disabled_runes() -> void:
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

	_halved_segment_index = RunRng.create_rng("challenge:fading_sector:r%d:s%d" % [
		GameManager.current_round,
		GameManager.turn_stamp,
	]).randi() % segment_count
	_apply_fading_sector_visuals()
	EventBus.challenge_changed.emit()


func _apply_fading_sector_visuals() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null or _halved_segment_index < 0:
		return

	tile_map.highlight_challenge_segment(_halved_segment_index)
	for hex: Hex in tile_map.get_hexes_in_segment(_halved_segment_index):
		if hex.active_tile_card == null:
			continue
		if hex.active_tile_card.type != TileCard.TileCardType.PRODUCER:
			continue
		hex.set_tile_card_challenge_modulate(Hex.RUNE_FADED_SECTOR_MODULATE)


func _clear_fading_sector_visuals() -> void:
	_halved_segment_index = -1
	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	tile_map.clear_challenge_segment_highlight()
	for hex: Hex in tile_map.map_data.values():
		hex.clear_tile_card_challenge_modulate()


func _get_tile_map() -> HexTileMap:
	if _tile_map != null and is_instance_valid(_tile_map):
		return _tile_map

	for node in get_tree().get_nodes_in_group("hex_map_group"):
		_tile_map = node as HexTileMap
		if _tile_map != null:
			return _tile_map
	return null


#region Debug

## Forces a challenge on the current round and applies its immediate effects.
func debug_activate_challenge(challenge_type: int) -> void:
	if not ALL_CHALLENGES.has(challenge_type):
		push_warning("ChallengeManager: invalid debug challenge type %d." % challenge_type)
		return

	var previous_challenge := active_challenge
	_restore_challenge_disabled_runes()
	_clear_fading_sector_visuals()
	active_challenge = challenge_type
	_apply_rush_hour_turn_cap(previous_challenge)

	match active_challenge:
		Type.BLACKOUT:
			_apply_blackout()
		Type.FADING_SECTOR:
			_pick_halved_segment()

	EventBus.challenge_changed.emit()
	play_reveal()


## Clears any sandbox-forced challenge and restores normal map visuals.
func debug_clear_challenge() -> void:
	var previous_challenge := active_challenge
	if previous_challenge == -1:
		return

	_restore_challenge_disabled_runes()
	_clear_fading_sector_visuals()
	active_challenge = -1
	_apply_rush_hour_turn_cap(previous_challenge)
	EventBus.challenge_banner_hidden.emit()
	EventBus.challenge_changed.emit()


func _apply_rush_hour_turn_cap(previous_challenge: int) -> void:
	var rush_hour_changed := (
		previous_challenge == Type.RUSH_HOUR
		or active_challenge == Type.RUSH_HOUR
	)
	if not rush_hour_changed:
		return

	var max_turns := get_max_turns_per_round()
	if GameManager.remaining_turns > max_turns:
		GameManager.remaining_turns = max_turns
	EventBus.turn_changed.emit()

#endregion

func capture_run_state() -> Dictionary:
	return {
		"scheduled_challenges": scheduled_challenges.duplicate(),
		"active_challenge": active_challenge,
		"halved_segment_index": _halved_segment_index,
	}


func apply_run_state(state: Dictionary) -> void:
	scheduled_challenges.clear()
	for challenge_type in state.get("scheduled_challenges", []):
		var normalized := _normalize_saved_challenge_type(int(challenge_type))
		if normalized >= 0:
			scheduled_challenges.append(normalized)

	active_challenge = _normalize_saved_challenge_type(int(state.get("active_challenge", -1)))
	_halved_segment_index = int(state.get("halved_segment_index", -1))
	_disabled_prior_states.clear()
	_tile_map = null


## Remaps saves that still reference the removed Chain Reaction challenge.
func _normalize_saved_challenge_type(challenge_type: int) -> int:
	const LEGACY_CHAIN_REACTION := 3
	if challenge_type == LEGACY_CHAIN_REACTION:
		return -1
	if challenge_type > LEGACY_CHAIN_REACTION:
		return challenge_type - 1
	return challenge_type


func restore_banner_after_load() -> void:
	# A queued reveal stays queued so the load does not spoil it before the merchant closes.
	if active_challenge == -1 or RoundFlow.has_armed_challenge_reveal():
		EventBus.challenge_banner_hidden.emit()
		return

	EventBus.challenge_banner_shown.emit(get_active_challenge_name(), true)


func refresh_challenge_visuals() -> void:
	if active_challenge == Type.FADING_SECTOR and _halved_segment_index >= 0:
		_apply_fading_sector_visuals()
	else:
		_clear_fading_sector_visuals()
