extends Node

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

# Manages phase challenges on phases 4, 8, and 12. Three challenges are picked at run start.

enum Type {
	BLACKOUT,
	RUSH_HOUR,
	SOLO_PACT,
	CHAIN_REACTION,
	TAXATION,
	FADING_SECTOR,
}

const CHALLENGE_PHASES := [3, 6, 9]

const ALL_CHALLENGES: Array[Type] = [
	Type.BLACKOUT,
	Type.RUSH_HOUR,
	Type.SOLO_PACT,
	Type.CHAIN_REACTION,
	Type.TAXATION,
	Type.FADING_SECTOR,
]

const CHALLENGE_INFO := {
	Type.BLACKOUT: {
		"name": "Blackout",
		"description": "Every turn, 5 random runes on the map are disabled.",
	},
	Type.RUSH_HOUR: {
		"name": "Rush Hour",
		"description": "You have 1 less turn to complete the phase.",
	},
	Type.SOLO_PACT: {
		"name": "Solo Pact",
		"description": "Only 1 card choice at the start of every turn.",
	},
	Type.CHAIN_REACTION: {
		"name": "Chain Reaction",
		"description": "Producer runes only activate through triggers from other runes.",
	},
	Type.TAXATION: {
		"name": "Taxation",
		"description": "Lose 1 gold on every support rune trigger.",
	},
	Type.FADING_SECTOR: {
		"name": "Fading Sector",
		"description": "Every turn, a random segment has its producer output halved.",
	},
}

# One challenge per entry in CHALLENGE_PHASES, chosen at run start.
var scheduled_challenges: Array[Type] = []
# Active challenge for the current phase; -1 when no challenge is running.
var active_challenge: int = -1

var _halved_segment_index := -1
# Saved is_active values so player toggles are restored after each turn's blackout.
var _disabled_prior_states: Dictionary = {}
var _tile_map: HexTileMap = null
# Set when entering a challenge phase; cleared after the post-merchant banner is shown.
var _pending_challenge_reveal := false


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.rune_activated.connect(_on_rune_activated)
	EventBus.merchant_closed.connect(_on_merchant_closed)


# Pick three unique challenges for phases 4, 8, and 12 at the start of a run.
func init_run() -> void:
	scheduled_challenges.clear()
	active_challenge = -1
	_halved_segment_index = -1
	_disabled_prior_states.clear()
	_pending_challenge_reveal = false
	_clear_fading_sector_visuals()

	var pool := ALL_CHALLENGES.duplicate()
	pool.shuffle()
	for i in CHALLENGE_PHASES.size():
		scheduled_challenges.append(pool[i])

	EventBus.challenge_schedule_changed.emit()


func on_phase_advanced(new_phase: int) -> void:
	_clear_fading_sector_visuals()
	active_challenge = get_challenge_for_phase(new_phase)
	_restore_challenge_disabled_runes()

	if active_challenge != -1:
		_pending_challenge_reveal = true
	else:
		EventBus.challenge_banner_hidden.emit()

	EventBus.challenge_changed.emit()


func is_completing_final_challenge_phase() -> bool:
	return (
		GameManager.current_phase == CHALLENGE_PHASES[-1]
		and get_challenge_for_phase(GameManager.current_phase) != -1
	)


func get_challenge_for_phase(phase: int) -> int:
	var phase_index := CHALLENGE_PHASES.find(phase)
	if phase_index == -1:
		return -1
	# Left panel can query before main.gd calls init_run() at run start.
	if phase_index >= scheduled_challenges.size():
		return -1
	return scheduled_challenges[phase_index]


func get_next_challenge_phase() -> int:
	for phase in CHALLENGE_PHASES:
		if phase > GameManager.current_phase:
			return phase
	return -1


func get_next_challenge_type() -> int:
	var next_phase := get_next_challenge_phase()
	if next_phase == -1:
		return -1
	return get_challenge_for_phase(next_phase)


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


func get_max_turns_per_phase() -> int:
	if active_challenge == Type.RUSH_HOUR:
		return GameManager.MAX_TURNS_PER_PHASE - 1
	return GameManager.MAX_TURNS_PER_PHASE


func get_runes_pack_size() -> int:
	if active_challenge == Type.SOLO_PACT:
		return 1
	return GameManager.RUNES_PACK_SIZE


func should_skip_primary_producer_activation(rune: Rune) -> bool:
	return active_challenge == Type.CHAIN_REACTION and rune.type == Rune.RuneType.PRODUCER


func get_producer_output_multiplier(tile: Hex) -> float:
	if active_challenge != Type.FADING_SECTOR or _halved_segment_index < 0:
		return 1.0
	if tile.active_rune == null or tile.active_rune.type != Rune.RuneType.PRODUCER:
		return 1.0

	var tile_map := _get_tile_map()
	if tile_map == null:
		return 1.0
	if tile_map.get_segment_index(tile.coordinates) != _halved_segment_index:
		return 1.0
	return 0.5


func _on_turn_started() -> void:
	if GameManager.is_in_post_victory_transition():
		return
	if active_challenge == Type.BLACKOUT:
		_clear_fading_sector_visuals()
		_apply_blackout()
	elif active_challenge == Type.FADING_SECTOR:
		_restore_challenge_disabled_runes()
		_pick_halved_segment()
	else:
		_restore_challenge_disabled_runes()
		_clear_fading_sector_visuals()


func _on_rune_activated(rune: Rune) -> void:
	if active_challenge != Type.TAXATION:
		return
	if rune.type != Rune.RuneType.SUPPORT:
		return
	if GoldManager.amount <= 0:
		return

	GoldManager.remove(1)
	var tile_map := _get_tile_map()
	if tile_map != null:
		var hex := tile_map.get_hex_for_rune(rune)
		if hex != null:
			var tile_pos := tile_map.base_layer.map_to_local(hex.coordinates)
			tile_map.create_floating_text(tile_pos, "-1 Gold", Color.GOLD)


func _on_merchant_closed() -> void:
	if not _pending_challenge_reveal or active_challenge == -1:
		return

	_pending_challenge_reveal = false
	AudioManager.play_sfx(UI_SOUNDS.CHALLENGE_START)
	EventBus.challenge_banner_shown.emit(get_active_challenge_name())


func _apply_blackout() -> void:
	_restore_challenge_disabled_runes()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	var hexes_with_runes := tile_map.get_all_hexes_with_runes()
	hexes_with_runes.shuffle()

	for i in mini(5, hexes_with_runes.size()):
		var hex := hexes_with_runes[i]
		var rune := hex.active_rune
		if rune == null:
			continue
		_disabled_prior_states[rune] = rune.is_active
		rune.is_active = false
		hex.refresh_rune_visual_state()


func _restore_challenge_disabled_runes() -> void:
	var tile_map := _get_tile_map()
	for rune: Rune in _disabled_prior_states:
		if is_instance_valid(rune):
			rune.is_active = _disabled_prior_states[rune]
			if tile_map != null:
				var hex := tile_map.get_hex_for_rune(rune)
				if hex != null:
					hex.refresh_rune_visual_state()
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

	_halved_segment_index = randi() % segment_count
	_apply_fading_sector_visuals()
	EventBus.challenge_changed.emit()


func _apply_fading_sector_visuals() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null or _halved_segment_index < 0:
		return

	tile_map.highlight_challenge_segment(_halved_segment_index)
	for hex: Hex in tile_map.get_hexes_in_segment(_halved_segment_index):
		if hex.active_rune == null:
			continue
		if hex.active_rune.type != Rune.RuneType.PRODUCER:
			continue
		hex.set_rune_challenge_modulate(Hex.RUNE_FADED_SECTOR_MODULATE)


func _clear_fading_sector_visuals() -> void:
	_halved_segment_index = -1
	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	tile_map.clear_challenge_segment_highlight()
	for hex: Hex in tile_map.map_data.values():
		hex.clear_rune_challenge_modulate()


func _get_tile_map() -> HexTileMap:
	if _tile_map != null and is_instance_valid(_tile_map):
		return _tile_map

	for node in get_tree().get_nodes_in_group("hex_map_group"):
		_tile_map = node as HexTileMap
		if _tile_map != null:
			return _tile_map
	return null
