extends Node

# Central coordinator for run flow: turns, scoring, phases, rune pools, and turn processing.

signal game_speed_changed(new_speed: float)

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
const RUNES_PACK_SIZE := 3
const MAX_TURNS_PER_PHASE := 5

# Set when a turn ends with enough score to meet the phase goal; consumed after rune selection.
var _pending_merchant_visit := false

#region Turn state

var _current_turn := 1
# Blocks player input while runes are resolving after end turn.
var _is_processing_turn := false

var current_turn: int:
	get:
		return _current_turn
	set(value):
		_current_turn = value
		if _current_turn > MAX_TURNS_PER_PHASE:
			Events.game_ended.emit()

var is_processing_turn: bool:
	get:
		return _is_processing_turn

#endregion

#region Score and phase progression

# Score needed to complete the current phase and open the merchant.
var required_score: int = 1100
# Applied each time required_score is met to scale difficulty across phases.
var required_score_multiplier: int = 2

var _total_score: int = 0
var _turn_score: int = 0
var _turn_multi: int = 1

var total_score: int:
	get:
		return _total_score
	set(value):
		_total_score = value
		Events.total_score_changed.emit()
		# Meeting the threshold advances the phase inside the setter.
		if _total_score >= required_score:
			required_score = required_score * required_score_multiplier + 750
			advance_phase()

var turn_score: int:
	get:
		return _turn_score
	set(value):
		_turn_score = value
		Events.turn_score_changed.emit()

var turn_multi: int:
	get:
		return _turn_multi
	set(value):
		_turn_multi = value
		Events.turn_multi_changed.emit()

#endregion

#region Runes pool and selection pack

# Every rune resource loaded from disk at startup.
var runes_pool: Array[Rune] = []
# Every enhancement resource loaded from disk at startup.
var enhancements_pool: Array[Enhancement] = []
# The three runes currently offered on the post-turn selection panel.
var runes_pack: Array[Rune] = []
# How many rune packs are queued; incremented each turn and consumed when the panel opens.
var _available_runes_packs: int = 0
# Gold cost to reroll the current pack; rises by 5 after each reroll.
var _runes_reroll_cost: int = 0

var available_runes_packs: int:
	get:
		return _available_runes_packs
	set(value):
		_available_runes_packs = max(0, value)
		Events.rune_pack_count_changed.emit()

var runes_reroll_cost: int:
	get:
		return _runes_reroll_cost
	set(value):
		_runes_reroll_cost = max(0, value)

#endregion

#region Rune activation tracking

# Cleared at turn start; filled as each rune resolves during turn processing.
var _runes_activated_this_turn: int = 0
var _activated_runes_this_turn: Array[Rune] = []

#endregion

#region Character and trigger order

# Chosen on the character selection screen; drives starting gold, hand, and trigger order.
var selected_character: PlayerCharacter.Type = PlayerCharacter.Type.SURVEYOR
var _trigger_order: TriggerOrderType.Type = TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT

var trigger_order: TriggerOrderType.Type:
	get:
		return _trigger_order
	set(value):
		if _trigger_order == value:
			return
		_trigger_order = value
		Events.trigger_order_changed.emit(_trigger_order)

#endregion

#region Game speed

var _game_speed: float = 1.0

var game_speed: float:
	get:
		return _game_speed
	set(value):
		_game_speed = clampf(value, 1.0, 3.0)
		game_speed_changed.emit(_game_speed)

#endregion

func _ready() -> void:
	_load_runes_from_directory("res://resources/runes/")
	_load_enhancements_from_directory("res://resources/enhancements/")

	if runes_pool.is_empty():
		push_error("No runes loaded into pool")
	else:
		create_runes_pack()

	if enhancements_pool.is_empty():
		push_warning("No enhancements loaded into pool")

	Events.turn_ended.connect(end_turn)
	Events.turn_started.connect(_on_turn_started)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		Events.turn_ended.emit()
		AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)

#region Turn flow

func end_turn() -> void:
	_is_processing_turn = true


func finish_turn_processing() -> void:
	_is_processing_turn = false

	# Score the turn before advancing counters so phase logic sees this turn's contribution.
	var pending_total_score := total_score + (turn_score * turn_multi)
	var should_advance_turn := current_turn <= MAX_TURNS_PER_PHASE and pending_total_score < required_score

	if pending_total_score >= required_score:
		_pending_merchant_visit = true

	total_score = pending_total_score
	turn_score = 0
	turn_multi = 1

	available_runes_packs += 1
	UiManager.show_runes_choice_panel.emit()
	Events.turn_started.emit()

	if should_advance_turn:
		current_turn += 1
		Events.turn_changed.emit()


func _on_turn_started() -> void:
	_runes_activated_this_turn = 0
	_activated_runes_this_turn.clear()
	GoldManager.reset_turn_tracking()


func consume_pending_merchant_visit() -> bool:
	if not _pending_merchant_visit:
		return false
	_pending_merchant_visit = false
	return true


func advance_phase() -> void:
	GoldManager.add(20)
	AudioManager.play_ui_sound(UI_SOUNDS.GOLD_GAINED)

	current_turn = 1
	Events.turn_changed.emit()
	Events.required_score_changed.emit()

#endregion

#region Rune activation API

func get_runes_activated_this_turn() -> int:
	return _runes_activated_this_turn


func has_rune_activated_this_turn(rune: Rune) -> bool:
	return _activated_runes_this_turn.has(rune)


func register_rune_activation(rune: Rune) -> void:
	_runes_activated_this_turn += 1
	_activated_runes_this_turn.append(rune)

#endregion

#region Runes pool loading and pack creation

# Recursively load every .tres rune under the runes folder, skipping duplicate ids.
# ResourceLoader.list_directory works in exported builds; DirAccess only sees .gd files in PCK.
func _load_runes_from_directory(dir_path: String) -> void:
	var normalized_path := dir_path
	if not normalized_path.ends_with("/"):
		normalized_path += "/"

	for entry in ResourceLoader.list_directory(normalized_path):
		if entry == "./" or entry == "../":
			continue

		if entry.ends_with("/"):
			# Visit subfolders first so organized copies win over legacy root duplicates.
			_load_runes_from_directory(normalized_path.path_join(entry.trim_suffix("/")))
			continue

		if not entry.ends_with(".tres"):
			continue

		var resource_path := normalized_path.path_join(entry)
		var rune := ResourceLoader.load(resource_path) as Rune
		if rune == null:
			push_error("Failed to load rune: " + resource_path)
			continue

		if _has_rune_with_id(rune.id):
			continue

		runes_pool.append(rune)


func _has_rune_with_id(rune_id: String) -> bool:
	for existing_rune in runes_pool:
		if existing_rune.id == rune_id:
			return true
	return false


# Load every .tres enhancement under the enhancements folder, skipping duplicate ids.
func _load_enhancements_from_directory(dir_path: String) -> void:
	var normalized_path := dir_path
	if not normalized_path.ends_with("/"):
		normalized_path += "/"

	for entry in ResourceLoader.list_directory(normalized_path):
		if entry == "./" or entry == "../":
			continue

		if entry.ends_with("/"):
			_load_enhancements_from_directory(normalized_path.path_join(entry.trim_suffix("/")))
			continue

		if not entry.ends_with(".tres"):
			continue

		var resource_path := normalized_path.path_join(entry)
		var enhancement := ResourceLoader.load(resource_path) as Enhancement
		if enhancement == null:
			push_error("Failed to load enhancement: " + resource_path)
			continue

		if _has_enhancement_with_id(enhancement.id):
			continue

		enhancements_pool.append(enhancement)


func _has_enhancement_with_id(enhancement_id: String) -> bool:
	for existing_enhancement in enhancements_pool:
		if existing_enhancement.id == enhancement_id:
			return true
	return false


# Pick three random runes for the selection panel.
# Only fills an empty pack so multiple end-turns can stack packs without overwriting.
func create_runes_pack() -> void:
	if not runes_pack.is_empty():
		return

	if runes_pool.is_empty():
		push_error("Cannot create runes pack: runes pool is empty")
		return

	var shuffled_pool := runes_pool.duplicate()
	shuffled_pool.shuffle()

	for i in mini(RUNES_PACK_SIZE, shuffled_pool.size()):
		runes_pack.append(shuffled_pool[i])

#endregion

func set_game_speed(speed: float) -> void:
	game_speed = speed
