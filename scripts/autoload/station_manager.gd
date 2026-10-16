extends Node

# Preload so typed arrays resolve during autoload parse.
const _StationTypeScript := preload("res://scripts/resources/station_type.gd")
const _StationPerkScript := preload("res://scripts/resources/station_perk.gd")

## Run-long station state: type, Meals served, level, and the level 3 pick.
## Stations start at level 1. A base station turns into a type when its regular spots hold that
## type's cards. A typed station that loses those cards resets to level 1 and becomes the first
## type it still satisfies, or a base station. Only typed stations count served Meals and level up.
## Level 3 unlocks the second Meal slot and offers a perk choice.
## Every change emits EventBus.station_state_changed. The board, badges and chips redraw from it.

const STATION_TYPE_PATHS: Array[String] = [
	"res://resources/stations/grill.tres",
	"res://resources/stations/cold_station.tres",
	"res://resources/stations/raw_bar.tres",
	"res://resources/stations/pastry_station.tres",
	"res://resources/stations/sauce_station.tres",
]
## Total Meals served (after gaining a type) to reach levels 2, 3 and 4.
const LEVEL_THRESHOLDS: Array[int] = [3, 7, 12]
const START_LEVEL := 1
const MAX_LEVEL := START_LEVEL + 3
const CHOICE_LEVEL := 3
const MEAL_SLOT_UNLOCK_LEVEL := 3
const BASE_STATION_NAME := "Station"

## Fired when the pending level 3 pick is made, or dropped because the station lost its type.
## HexTurnResolver waits on this mid-Hour.
signal choice_resolved(segment_index: int)


## One station's run state. type is null for a base station. choice is -1 until picked.
class Station:
	var type: StationType = null
	var served := 0
	var level := START_LEVEL
	var choice := -1

	func to_dict() -> Dictionary:
		return {
			"type_id": type.id if type != null else "",
			"served": served,
			"level": level,
			"choice": choice,
		}


var _types: Array[StationType] = []
var _types_by_id: Dictionary = {}
var _stations: Array[Station] = []
## Stations waiting on a level 3 pick, oldest first.
var _pending_choices: Array[int] = []
## Live board. HexTileMap registers itself, so headless boards work without the main scene.
var _board: HexTileMap = null
## True while a deferred evaluate_station_types is waiting for the end of the frame.
var _evaluation_queued := false


func _ready() -> void:
	for path: String in STATION_TYPE_PATHS:
		var station_type := load(path) as StationType
		if station_type == null:
			push_error("StationManager: missing station type at %s." % path)
			continue
		_types.append(station_type)
		_types_by_id[station_type.id] = station_type
	_reset_stations()
	EventBus.card_played.connect(_on_card_played)
	EventBus.turn_started.connect(evaluate_station_types)


func bind_board(board: HexTileMap) -> void:
	_board = board


func unbind_board(board: HexTileMap) -> void:
	if _board == board:
		_board = null


func reset_for_new_run() -> void:
	_reset_stations()
	_pending_choices.clear()
	_emit_all_changed()


func _reset_stations() -> void:
	_stations.clear()
	for _i in HexMapLayout.BOARD_ROW_LENGTHS.size():
		_stations.append(Station.new())


#region --- Queries ---

func get_station_type(segment_index: int) -> StationType:
	var station := _station(segment_index)
	return station.type if station != null else null


func get_station_name(segment_index: int) -> String:
	var station_type := get_station_type(segment_index)
	return station_type.display_name if station_type != null else BASE_STATION_NAME


func get_level(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.level if station != null else START_LEVEL


func get_served(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.served if station != null else 0


## Meals served needed for the next level, or -1 at max level.
func get_next_threshold(segment_index: int) -> int:
	var level := get_level(segment_index)
	if level >= MAX_LEVEL:
		return -1
	return LEVEL_THRESHOLDS[level - START_LEVEL]


## Meals served needed for the current level. 0 at the starting level.
func get_current_threshold(segment_index: int) -> int:
	var level := get_level(segment_index)
	if level <= START_LEVEL:
		return 0
	return LEVEL_THRESHOLDS[level - START_LEVEL - 1]


## Index into the type's choice_options, or -1 when nothing was picked.
func get_choice(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.choice if station != null else -1


func get_chosen_perk(segment_index: int) -> StationPerk:
	var options := get_choice_options(segment_index)
	var choice := get_choice(segment_index)
	if choice < 0 or choice >= options.size():
		return null
	return options[choice]


func get_choice_options(segment_index: int) -> Array[StationPerk]:
	var station_type := get_station_type(segment_index)
	if station_type == null:
		return []
	return station_type.choice_options


## Perks active on a station right now: the level perk plus the level 3 pick.
func get_active_perks(segment_index: int) -> Array[StationPerk]:
	var perks: Array[StationPerk] = []
	var station_type := get_station_type(segment_index)
	if station_type == null:
		return perks
	var level_perk := station_type.perk_for_level(get_level(segment_index))
	if level_perk != null:
		perks.append(level_perk)
	var chosen := get_chosen_perk(segment_index)
	if chosen != null:
		perks.append(chosen)
	return perks


func is_meal_slot_unlocked(segment_index: int, meal_slot_index: int) -> bool:
	return meal_slot_index <= 0 or get_level(segment_index) >= MEAL_SLOT_UNLOCK_LEVEL


## True for the second Meal slot of a station below level 3.
func is_meal_slot_locked(coords: Vector2i) -> bool:
	if _board == null:
		return false
	var meal_slot_index := _board.get_meal_slot_index(coords)
	if meal_slot_index < 0:
		return false
	return not is_meal_slot_unlocked(_board.get_segment_index(coords), meal_slot_index)

#endregion --- Queries ---


#region --- Perks ---

## Whole-activation scale from station perks and from cards on the same station (Grape).
func output_scale_for(tile: Hex, card: TileCard) -> float:
	if tile == null or tile.map == null or card == null:
		return 1.0
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	var scale := 1.0
	for perk: StationPerk in get_active_perks(segment_index):
		if perk.matches(card):
			scale *= perk.output_scale
	for hex: Hex in tile.map.get_hexes_in_segment(segment_index):
		var neighbour := hex.active_tile_card
		if neighbour != null and neighbour != card:
			scale *= neighbour.station_output_scale_for(card)
	return scale


## Flat Flavour a station adds after an Ingredient pays.
func flat_flavour_bonus_for(tile: Hex, card: TileCard) -> int:
	if tile == null or tile.map == null or card == null:
		return 0
	if card.type != TileCard.TileCardType.INGREDIENT or card.product != TileCard.Product.FLAVOUR:
		return 0
	var bonus := 0
	for perk: StationPerk in get_active_perks(tile.map.get_segment_index(tile.coordinates)):
		if perk.matches(card):
			bonus += perk.flat_flavour
	return bonus


## Pays the station's flat bonus for an activation that just resolved.
func apply_flat_bonus(tile: Hex, card: TileCard) -> void:
	var bonus := flat_flavour_bonus_for(tile, card)
	if bonus <= 0:
		return
	var station_type := get_station_type(tile.map.get_segment_index(tile.coordinates))
	card.add_station_bonus_flavour(tile, bonus, station_type.color)

#endregion --- Perks ---


#region --- Type and level changes ---

func _on_card_played(_card_ui: CardUI) -> void:
	evaluate_station_types()


## Runs evaluate_station_types once at the end of the frame. Board edits call this, so a swap
## (remove both, then reseat) is judged on the final board, not the half-swapped one.
func queue_type_evaluation() -> void:
	if _evaluation_queued:
		return
	_evaluation_queued = true
	_run_queued_evaluation.call_deferred()


func _run_queued_evaluation() -> void:
	_evaluation_queued = false
	evaluate_station_types()


## Base stations take the first type their regular spots satisfy. A typed station keeps its type
## while it stays satisfied. Once it is not, its progress resets and it takes the first type it
## still satisfies, or turns back into a base station.
func evaluate_station_types() -> void:
	if _board == null:
		return
	for segment_index in _stations.size():
		var station := _stations[segment_index]
		var cards := _board.get_regular_tile_cards(segment_index)
		if station.type != null and station.type.is_satisfied_by(cards):
			continue
		var new_type: StationType = null
		for station_type: StationType in _types:
			if station_type.is_satisfied_by(cards):
				new_type = station_type
				break
		if new_type == station.type:
			continue
		if station.type != null:
			_reset_progress(segment_index)
		station.type = new_type
		EventBus.station_type_changed.emit(segment_index, new_type.id if new_type != null else "")
		EventBus.station_state_changed.emit(segment_index)


## Back to level 1 with no Meals served and no level 3 pick. Drops a pick still waiting.
func _reset_progress(segment_index: int) -> void:
	var station := _stations[segment_index]
	station.served = 0
	station.level = START_LEVEL
	station.choice = -1
	var was_showing := get_pending_choice_segment() == segment_index
	_pending_choices.erase(segment_index)
	if not was_showing:
		return
	choice_resolved.emit(segment_index)
	if has_pending_choice():
		EventBus.station_choice_requested.emit(get_pending_choice_segment())


## One served Meal. Levels the station when it crosses a threshold. Base stations do not progress.
func record_serving(segment_index: int) -> void:
	var station := _station(segment_index)
	if station == null or station.type == null:
		return
	station.served += 1
	while station.level < MAX_LEVEL and station.served >= LEVEL_THRESHOLDS[station.level - START_LEVEL]:
		station.level += 1
		EventBus.station_leveled_up.emit(segment_index, station.level)
		if station.level == MEAL_SLOT_UNLOCK_LEVEL:
			EventBus.meal_slot_unlocked.emit(segment_index)
		if station.level == CHOICE_LEVEL:
			_queue_choice(segment_index)
	EventBus.station_state_changed.emit(segment_index)

#endregion --- Type and level changes ---


#region --- Level 3 choice ---

func has_pending_choice() -> bool:
	return not _pending_choices.is_empty()


## Oldest station waiting on a pick, or -1.
func get_pending_choice_segment() -> int:
	return _pending_choices[0] if not _pending_choices.is_empty() else -1


## Locks in a pick. The popup calls this. Opens the next pending pick if there is one.
func resolve_choice(segment_index: int, option_index: int) -> void:
	if not _pending_choices.has(segment_index):
		return
	_pending_choices.erase(segment_index)
	_stations[segment_index].choice = option_index
	EventBus.station_state_changed.emit(segment_index)
	choice_resolved.emit(segment_index)
	if has_pending_choice():
		EventBus.station_choice_requested.emit(get_pending_choice_segment())


func _queue_choice(segment_index: int) -> void:
	if get_choice(segment_index) >= 0 or _pending_choices.has(segment_index):
		return
	if get_choice_options(segment_index).is_empty():
		return
	_pending_choices.append(segment_index)
	# Bots and skipped presentation take the first option instead of waiting on a popup.
	if GameManager.skip_presentation:
		resolve_choice(segment_index, 0)
		return
	if _pending_choices.size() == 1:
		EventBus.station_choice_requested.emit(segment_index)

#endregion --- Level 3 choice ---


#region --- Save ---

func capture_run_state() -> Dictionary:
	var stations: Array = []
	for station: Station in _stations:
		stations.append(station.to_dict())
	return {"stations": stations, "pending_choices": _pending_choices.duplicate()}


func apply_run_state(state: Dictionary) -> void:
	_reset_stations()
	_pending_choices.clear()
	var saved: Array = state.get("stations", [])
	for i in mini(saved.size(), _stations.size()):
		var entry: Dictionary = saved[i]
		var station := _stations[i]
		station.type = _types_by_id.get(String(entry.get("type_id", ""))) as StationType
		station.served = int(entry.get("served", 0))
		station.level = clampi(int(entry.get("level", START_LEVEL)), START_LEVEL, MAX_LEVEL)
		station.choice = int(entry.get("choice", -1))
	for segment_index in state.get("pending_choices", []):
		if _station(int(segment_index)) != null:
			_pending_choices.append(int(segment_index))
	_emit_all_changed()


## Re-opens a pick that was waiting when the run was saved.
func restore_pending_choice_after_load() -> void:
	if has_pending_choice():
		EventBus.station_choice_requested.emit(get_pending_choice_segment())

#endregion --- Save ---


func _station(segment_index: int) -> Station:
	if segment_index < 0 or segment_index >= _stations.size():
		return null
	return _stations[segment_index]


func _emit_all_changed() -> void:
	for i in _stations.size():
		EventBus.station_state_changed.emit(i)
