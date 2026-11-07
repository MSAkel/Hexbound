extends Node

# Preload so typed arrays resolve during autoload parse.
const _StationTypeScript := preload("res://scripts/resources/station_type.gd")
const _StationPerkScript := preload("res://scripts/resources/station_perk.gd")

## Run-long station state: type, Meals served, level, the level 3 and level 6 picks, and per-station
## perk state. Stations start at level 1. A base station turns into a type when its regular spots hold
## that type's cards. A typed station that loses those cards resets to level 1 and becomes the first
## type it still satisfies, or a base station. Only typed stations count served Meals and level up.
## Level 3 unlocks the second Meal slot and offers a perk choice. Level 6 offers a second choice.
## Every change emits EventBus.station_state_changed. The board, badges and chips redraw from it.
## Perks live on StationPerk resources; this manager calls their hooks (see station_perk.gd).

const STATION_TYPE_PATHS: Array[String] = [
	"res://resources/stations/grilling_station.tres",
	"res://resources/stations/cold_station.tres",
	"res://resources/stations/fish_station.tres",
	"res://resources/stations/pastry_station.tres",
	"res://resources/stations/sauce_station.tres",
	"res://resources/stations/roasting_station.tres",
	"res://resources/stations/bar_station.tres",
	# Fry takes any Ingredients, so it is tried last. Its Deep Fryer still wins a tie on a new row
	# (see evaluate_station_types).
	"res://resources/stations/fry_station.tres",
]
## Old ids still found in saves.
const LEGACY_TYPE_IDS := {"raw_bar": "fish_station"}
## Total Meals served (a running total after gaining a type) to reach levels 2 to 6.
## Some chefs change these per station type (get_level_thresholds).
const LEVEL_THRESHOLDS: Array[int] = [2, 5, 8, 12, 16]
const START_LEVEL := 1
const MAX_LEVEL := START_LEVEL + 5
const CHOICE_LEVEL := 3
const CAPSTONE_LEVEL := 6
const MEAL_SLOT_UNLOCK_LEVEL := 3
const BASE_STATION_NAME := "Station"

## Fired when a pending pick is made, or dropped because the station lost its type.
## HexTurnResolver waits on this mid-Hour.
signal choice_resolved(segment_index: int)


## One station's run state. type is null for a base station. choice and capstone are -1 until picked.
## state holds perk progress (counters, flags). It must stay JSON friendly and resets with the level.
class Station:
	var type: StationType = null
	var served := 0
	var level := START_LEVEL
	var choice := -1
	var capstone := -1
	var state: Dictionary = {}
	## Difficulty lock: the second Meal slot stays shut until MEAL_SLOT_UNLOCK_LEVEL. Set per run.
	var meal_slot_locked := false

	func to_dict() -> Dictionary:
		return {
			"type_id": type.id if type != null else "",
			"served": served,
			"level": level,
			"choice": choice,
			"capstone": capstone,
			"state": state.duplicate(true),
			"meal_slot_locked": meal_slot_locked,
		}


var _types: Array[StationType] = []
var _types_by_id: Dictionary = {}
var _stations: Array[Station] = []
## Stations waiting on a pick, oldest first.
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


func get_board() -> HexTileMap:
	return _board


func reset_for_new_run() -> void:
	_reset_stations()
	_roll_meal_slot_locks()
	_pending_choices.clear()
	_emit_all_changed()


## Picks which stations lock their second Meal slot for this run. Seeded, so a seed replays it.
func _roll_meal_slot_locks() -> void:
	var count := mini(
		Difficulty.get_locked_meal_slot_station_count(GameManager.selected_difficulty),
		_stations.size()
	)
	var order: Array = range(_stations.size())
	RunRng.shuffle_with(RunRng.create_rng("meal_slot_locks"), order)
	for i in _stations.size():
		_stations[i].meal_slot_locked = false
	for i in count:
		_stations[int(order[i])].meal_slot_locked = true


func _reset_stations() -> void:
	_stations.clear()
	for _i in HexMapLayout.BOARD_ROW_LENGTHS.size():
		_stations.append(Station.new())


#region --- Queries ---

func get_station_type(segment_index: int) -> StationType:
	var station := _station(segment_index)
	return station.type if station != null else null


func get_station_type_id(segment_index: int) -> String:
	var station_type := get_station_type(segment_index)
	return station_type.id if station_type != null else ""


func get_station_name(segment_index: int) -> String:
	var station_type := get_station_type(segment_index)
	return station_type.display_name if station_type != null else BASE_STATION_NAME


func get_level(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.level if station != null else START_LEVEL


func get_served(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.served if station != null else 0


func get_station_count() -> int:
	return _stations.size()


## Level 2 to 6 thresholds for a station of this type with the current chef and difficulty.
## Difficulty adds its extra Meals per step, so the nth threshold rises by n times that.
func get_level_thresholds(station_type: StationType) -> Array[int]:
	var thresholds := GameManager.chef.level_thresholds(station_type, LEVEL_THRESHOLDS)
	if thresholds.size() != LEVEL_THRESHOLDS.size():
		thresholds = LEVEL_THRESHOLDS
	var extra := Difficulty.get_station_level_extra_meals(GameManager.selected_difficulty)
	if extra <= 0:
		return thresholds
	var scaled: Array[int] = []
	for i in thresholds.size():
		scaled.append(thresholds[i] + extra * (i + 1))
	return scaled


## Meals served needed for the next level, or -1 at max level.
func get_next_threshold(segment_index: int) -> int:
	var level := get_level(segment_index)
	if level >= MAX_LEVEL:
		return -1
	return get_level_thresholds(get_station_type(segment_index))[level - START_LEVEL]


## Meals served needed for the current level. 0 at the starting level.
func get_current_threshold(segment_index: int) -> int:
	var level := get_level(segment_index)
	if level <= START_LEVEL:
		return 0
	return get_level_thresholds(get_station_type(segment_index))[level - START_LEVEL - 1]


## Index into the type's choice_options, or -1 when nothing was picked.
func get_choice(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.choice if station != null else -1


## Index into the type's capstone_options, or -1 when nothing was picked.
func get_capstone_choice(segment_index: int) -> int:
	var station := _station(segment_index)
	return station.capstone if station != null else -1


func get_chosen_perk(segment_index: int) -> StationPerk:
	var station_type := get_station_type(segment_index)
	var choice := get_choice(segment_index)
	if station_type == null or choice < 0 or choice >= station_type.choice_options.size():
		return null
	return station_type.choice_options[choice]


func get_capstone_perk(segment_index: int) -> StationPerk:
	var station_type := get_station_type(segment_index)
	var choice := get_capstone_choice(segment_index)
	if station_type == null or choice < 0 or choice >= station_type.capstone_options.size():
		return null
	return station_type.capstone_options[choice]


## Every station type, in the order evaluate_station_types tries them.
func get_station_types() -> Array[StationType]:
	return _types


## Level 3 and level 6 perks this station has: the picks, or every option when the chef
## takes every pick (Chef de Cuisine). Station tooltips list these.
func get_picked_perks(segment_index: int) -> Array[StationPerk]:
	var perks: Array[StationPerk] = []
	var station_type := get_station_type(segment_index)
	if station_type == null:
		return perks
	if GameManager.chef.takes_every_station_pick():
		var level := get_level(segment_index)
		if level >= CHOICE_LEVEL:
			perks.append_array(station_type.choice_options)
		if level >= CAPSTONE_LEVEL:
			perks.append_array(station_type.capstone_options)
		return perks
	var chosen := get_chosen_perk(segment_index)
	if chosen != null:
		perks.append(chosen)
	var capstone := get_capstone_perk(segment_index)
	if capstone != null:
		perks.append(capstone)
	return perks


## Level of the pick this station is waiting on (CHOICE_LEVEL or CAPSTONE_LEVEL), or 0.
## Always 0 when the chef takes every pick, so no popup opens.
func get_pending_choice_level(segment_index: int) -> int:
	var station := _station(segment_index)
	if station == null or station.type == null:
		return 0
	if GameManager.chef.takes_every_station_pick():
		return 0
	if station.level >= CHOICE_LEVEL and station.choice < 0 and not station.type.choice_options.is_empty():
		return CHOICE_LEVEL
	if station.level >= CAPSTONE_LEVEL and station.capstone < 0 and not station.type.capstone_options.is_empty():
		return CAPSTONE_LEVEL
	return 0


## Options for the pick this station is waiting on (level 3 first, then level 6).
func get_choice_options(segment_index: int) -> Array[StationPerk]:
	var station_type := get_station_type(segment_index)
	if station_type == null:
		return []
	if get_pending_choice_level(segment_index) == CAPSTONE_LEVEL:
		return station_type.capstone_options
	return station_type.choice_options


## Perks active on a station right now: the level perk plus the level 3 and level 6 picks.
func get_active_perks(segment_index: int) -> Array[StationPerk]:
	var perks: Array[StationPerk] = []
	var station_type := get_station_type(segment_index)
	if station_type == null:
		return perks
	var level_perk := station_type.perk_for_level(get_level(segment_index))
	if level_perk != null:
		perks.append(level_perk)
	perks.append_array(get_picked_perks(segment_index))
	return perks


## True when a station at level 2 or higher names this card's kind for the extra card-pick card
## (CardLoot.station_extra_card). The perk's draw_tags / draw_meal_categories define the kind.
func is_extra_card_kind(card: TileCard) -> bool:
	for seg in _stations.size():
		for perk: StationPerk in get_active_perks(seg):
			if perk.draw_weight_for(card) > 1.0:
				return true
	return false


## Flat Flavour of this station's current level perk. Spill-over perks (Charred Vegetables) lend it.
func get_level_flat_flavour(segment_index: int) -> int:
	var station_type := get_station_type(segment_index)
	if station_type == null:
		return 0
	var level_perk := station_type.perk_for_level(get_level(segment_index))
	return level_perk.flat_flavour if level_perk != null else 0


## True when this station's second Meal slot is locked by difficulty until MEAL_SLOT_UNLOCK_LEVEL.
func has_meal_slot_lock(segment_index: int) -> bool:
	var station := _station(segment_index)
	return station != null and station.meal_slot_locked


func is_meal_slot_unlocked(segment_index: int, meal_slot_index: int) -> bool:
	if meal_slot_index <= 0 or not has_meal_slot_lock(segment_index):
		return true
	return get_level(segment_index) >= MEAL_SLOT_UNLOCK_LEVEL


## True for a difficulty-locked second Meal slot on a station below level 3.
func is_meal_slot_locked(coords: Vector2i) -> bool:
	if _board == null:
		return false
	var meal_slot_index := _board.get_meal_slot_index(coords)
	if meal_slot_index < 0:
		return false
	return not is_meal_slot_unlocked(_board.get_segment_index(coords), meal_slot_index)

#endregion --- Queries ---


#region --- Helpers for perk scripts ---

## Perk progress for a station. Reset when the station loses its type.
func get_state(segment_index: int) -> Dictionary:
	var station := _station(segment_index)
	return station.state if station != null else {}


## Rows either side of this one that are on the board.
func adjacent_segments(segment_index: int) -> Array[int]:
	var result: Array[int] = []
	for side: int in [segment_index - 1, segment_index + 1]:
		if side >= 0 and side < _stations.size():
			result.append(side)
	return result


## The row that triggers right after this one, or -1 for the bottom station.
func next_segment(segment_index: int) -> int:
	var next := segment_index + 1
	return next if next < _stations.size() else -1


func segments_of_type(type_id: String) -> Array[int]:
	var result: Array[int] = []
	for i in _stations.size():
		if get_station_type_id(i) == type_id:
			result.append(i)
	return result


func is_type_present(type_id: String) -> bool:
	return not segments_of_type(type_id).is_empty()


func is_type_adjacent(segment_index: int, type_id: String) -> bool:
	for side: int in adjacent_segments(segment_index):
		if get_station_type_id(side) == type_id:
			return true
	return false


## 1 on the Day's first Hour.
func hour_number() -> int:
	return maxi(1, GameManager.get_turn_number())


## Meal hexes on a row (Meal slots that hold a Meal), in trigger order.
func meal_hexes(segment_index: int) -> Array[Hex]:
	var result: Array[Hex] = []
	if _board == null or segment_index < 0 or segment_index >= _board.get_segment_count():
		return result
	for hex: Hex in _board.get_hexes_in_segment(segment_index):
		if hex.active_tile_card is MealCard:
			result.append(hex)
	return result


## Ingredient hexes on a row, in trigger order.
func ingredient_hexes(segment_index: int) -> Array[Hex]:
	var result: Array[Hex] = []
	if _board == null or segment_index < 0 or segment_index >= _board.get_segment_count():
		return result
	for hex: Hex in _board.get_hexes_in_segment(segment_index):
		var card := hex.active_tile_card
		if card != null and card.type == TileCard.TileCardType.INGREDIENT:
			result.append(hex)
	return result


## Regular-spot cards on a row.
func station_cards(segment_index: int) -> Array[TileCard]:
	if _board == null:
		return []
	return _board.get_regular_tile_cards(segment_index)


func segment_of_tile(tile: Hex) -> int:
	if tile == null or tile.map == null:
		return -1
	return tile.map.get_segment_index(tile.coordinates)


## True when the Meal counts as category: its own category, or one a perk on its station adds.
func meal_counts_as(meal: MealCard, tile: Hex, category: int) -> bool:
	if meal == null:
		return false
	if int(meal.meal_category) == category:
		return true
	var seg := segment_of_tile(tile)
	if seg < 0:
		return false
	for perk: StationPerk in get_active_perks(seg):
		if perk.meal_counts_as(seg, meal, category):
			return true
	return false


## True when a perk on the card's station makes the Deep Fryer trigger it once more (Tempura).
func gets_extra_fryer_trigger(tile: Hex, card: TileCard) -> bool:
	var seg := segment_of_tile(tile)
	if seg < 0:
		return false
	for perk: StationPerk in get_active_perks(seg):
		if perk.gets_extra_fryer_trigger(seg, card):
			return true
	return false


## Rows whose Beverages count as served on segment_index: its own, plus Bars that share theirs.
func beverage_source_segments(segment_index: int) -> Array[int]:
	var result: Array[int] = [segment_index]
	for side: int in adjacent_segments(segment_index):
		for perk: StationPerk in get_active_perks(side):
			if perk.shares_beverages_with(side, segment_index):
				result.append(side)
				break
	return result


## Garnishes target from a card's activation, with the usual float. Returns false at the cap.
## extra adds more stacks on top (Sunday Roast, Sauce level 3 option B).
func garnish_from(source_tile: Hex, source_card: TileCard, target: TileCard, stacks: int = 1) -> bool:
	if target == null:
		return false
	var landed := false
	for _i in maxi(stacks, 1):
		if target.add_garnish():
			landed = true
	if landed and source_card != null and source_tile != null:
		source_card._create_garnish_floating_text(source_tile, target)
	return landed


## Garnish given by a Sauce & Dip meal. Perks on the target's station can make it count twice.
func sauce_garnish(source_tile: Hex, source_card: TileCard, target_tile: Hex, target: TileCard, stacks: int = 1) -> bool:
	var source_seg := segment_of_tile(source_tile)
	var target_seg := segment_of_tile(target_tile)
	var extra := 0
	if target_seg >= 0:
		for perk: StationPerk in get_active_perks(target_seg):
			extra += perk.extra_sauce_garnish_stacks(target_seg, source_seg)
	return garnish_from(source_tile, source_card, target, stacks + extra)

#endregion --- Helpers for perk scripts ---


#region --- Perks ---

## Whole-activation scale from station perks and from cards on the same station (Grape).
func output_scale_for(tile: Hex, card: TileCard) -> float:
	if tile == null or tile.map == null or card == null:
		return 1.0
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	var scale := 1.0
	for perk: StationPerk in get_active_perks(segment_index):
		scale *= perk.output_scale_on_station(segment_index, tile, card)
	for other in _stations.size():
		if other == segment_index:
			continue
		for perk: StationPerk in get_active_perks(other):
			scale *= perk.output_scale_elsewhere(other, segment_index, tile, card)
	for hex: Hex in tile.map.get_hexes_in_segment(segment_index):
		var neighbour := hex.active_tile_card
		if neighbour != null and neighbour != card:
			scale *= neighbour.station_output_scale_for(card)
	for side_index: int in [segment_index - 1, segment_index + 1]:
		if side_index < 0 or side_index >= tile.map.get_segment_count():
			continue
		for hex: Hex in tile.map.get_hexes_in_segment(side_index):
			var side_card := hex.active_tile_card
			if side_card != null and side_card != card:
				scale *= side_card.neighbour_station_output_scale_for(card, hex)
	return scale


## Flat Flavour station perks add to an Ingredient's base amount, before every multiplier.
func flat_flavour_bonus_for(tile: Hex, card: TileCard) -> int:
	if tile == null or tile.map == null or card == null:
		return 0
	if card.type != TileCard.TileCardType.INGREDIENT or card.product != TileCard.Product.FLAVOUR:
		return 0
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	var bonus := 0
	for perk: StationPerk in get_active_perks(segment_index):
		bonus += perk.flat_flavour_on_station(segment_index, tile, card)
	for other in _stations.size():
		if other == segment_index:
			continue
		for perk: StationPerk in get_active_perks(other):
			bonus += perk.flat_flavour_elsewhere(other, segment_index, tile, card)
	return maxi(bonus, 0)


func before_card_triggers(tile: Hex, card: TileCard) -> void:
	var seg := segment_of_tile(tile)
	if seg < 0:
		return
	for perk: StationPerk in get_active_perks(seg):
		perk.before_card_triggers(seg, tile, card)


func after_card_triggered(tile: Hex, card: TileCard) -> void:
	var seg := segment_of_tile(tile)
	if seg < 0:
		return
	for perk: StationPerk in get_active_perks(seg):
		perk.after_card_triggered(seg, tile, card)


## Every station's perks see every served Meal, so cross-station perks (Digestif) can react.
func on_meal_served(tile: Hex, meal: MealCard) -> void:
	var meal_seg := segment_of_tile(tile)
	for seg in _stations.size():
		for perk: StationPerk in get_active_perks(seg):
			perk.on_meal_served(seg, meal_seg, tile, meal)


## Before the first card of an Hour triggers. Clears per-Hour perk flags first.
func on_hour_started() -> void:
	for seg in _stations.size():
		var state := get_state(seg)
		for key: Variant in state.keys():
			if String(key).begins_with("hour_"):
				state.erase(key)
	for seg in _stations.size():
		for perk: StationPerk in get_active_perks(seg):
			perk.on_hour_started(seg)


func on_day_started() -> void:
	for seg in _stations.size():
		for perk: StationPerk in get_active_perks(seg):
			perk.on_day_started(seg)


## Day-end perks, then every Garnish still waiting on the board is cleared.
func on_day_ended() -> void:
	for seg in _stations.size():
		for perk: StationPerk in get_active_perks(seg):
			perk.on_day_ended(seg)
		var state := get_state(seg)
		for key: Variant in state.keys():
			if String(key).begins_with("day_") or String(key).begins_with("hour_"):
				state.erase(key)
	if _board == null:
		return
	for hex: Hex in _board.get_hexes_in_trigger_order():
		if hex.active_tile_card != null:
			hex.active_tile_card.clear_garnish()

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
## still satisfies, or turns back into a base station. When a row meets several setups at once,
## a type that names a specific card (Fry's Deep Fryer) wins over the rest.
func evaluate_station_types() -> void:
	if _board == null:
		return
	for segment_index in _stations.size():
		var station := _stations[segment_index]
		var cards := _board.get_regular_tile_cards(segment_index)
		if station.type != null and station.type.is_satisfied_by(cards):
			continue
		var new_type := _first_satisfied_type(cards)
		if new_type == station.type:
			continue
		if station.type != null:
			_reset_progress(segment_index)
		station.type = new_type
		EventBus.station_type_changed.emit(segment_index, new_type.id if new_type != null else "")
		EventBus.station_state_changed.emit(segment_index)


## Type a row with these regular-spot cards becomes. Types that name a specific card come first,
## then the rest in STATION_TYPE_PATHS order. Null when no setup is met.
func _first_satisfied_type(cards: Array[TileCard]) -> StationType:
	var fallback: StationType = null
	for station_type: StationType in _types:
		if not station_type.is_satisfied_by(cards):
			continue
		if not station_type.required_card_ids.is_empty():
			return station_type
		if fallback == null:
			fallback = station_type
	return fallback


## Back to level 1 with no Meals served, no picks and no perk progress. Drops a pick still waiting.
func _reset_progress(segment_index: int) -> void:
	var station := _stations[segment_index]
	station.served = 0
	station.level = START_LEVEL
	station.choice = -1
	station.capstone = -1
	station.state = {}
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
	var thresholds := get_level_thresholds(station.type)
	while station.level < MAX_LEVEL and station.served >= thresholds[station.level - START_LEVEL]:
		station.level += 1
		EventBus.station_leveled_up.emit(segment_index, station.level)
		if station.level == MEAL_SLOT_UNLOCK_LEVEL and station.meal_slot_locked:
			EventBus.meal_slot_unlocked.emit(segment_index)
		if station.level == CHOICE_LEVEL or station.level == CAPSTONE_LEVEL:
			_queue_choice(segment_index)
	EventBus.station_state_changed.emit(segment_index)

#endregion --- Type and level changes ---


#region --- Level 3 and level 6 choices ---

func has_pending_choice() -> bool:
	return not _pending_choices.is_empty()


## Oldest station waiting on a pick, or -1.
func get_pending_choice_segment() -> int:
	return _pending_choices[0] if not _pending_choices.is_empty() else -1


## Locks in the pick the station is waiting on. The popup calls this. Opens the next pending pick.
func resolve_choice(segment_index: int, option_index: int) -> void:
	if not _pending_choices.has(segment_index):
		return
	var station := _stations[segment_index]
	if get_pending_choice_level(segment_index) == CAPSTONE_LEVEL:
		station.capstone = option_index
	else:
		station.choice = option_index
	_pending_choices.erase(segment_index)
	EventBus.station_state_changed.emit(segment_index)
	choice_resolved.emit(segment_index)
	# A station that skipped past level 3 straight to 6 still owes its level 6 pick.
	if get_pending_choice_level(segment_index) != 0:
		_queue_choice(segment_index)
		return
	if has_pending_choice():
		EventBus.station_choice_requested.emit(get_pending_choice_segment())


func _queue_choice(segment_index: int) -> void:
	if get_pending_choice_level(segment_index) == 0 or _pending_choices.has(segment_index):
		return
	_pending_choices.append(segment_index)
	# Skipped presentation takes the first option instead of waiting on a popup.
	# The playtest bot answers station_choice_requested itself.
	if GameManager.skip_presentation and not GameManager.playtest_real_day_flow:
		resolve_choice(segment_index, 0)
		return
	if _pending_choices.size() == 1:
		EventBus.station_choice_requested.emit(segment_index)

#endregion --- Level 3 and level 6 choices ---


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
	# Saves from before per-station locks get this run's locks rolled from the seed.
	var has_saved_locks := not saved.is_empty()
	for i in mini(saved.size(), _stations.size()):
		var entry: Dictionary = saved[i]
		var station := _stations[i]
		var type_id := String(entry.get("type_id", ""))
		type_id = String(LEGACY_TYPE_IDS.get(type_id, type_id))
		station.type = _types_by_id.get(type_id) as StationType
		station.served = int(entry.get("served", 0))
		station.level = clampi(int(entry.get("level", START_LEVEL)), START_LEVEL, MAX_LEVEL)
		station.choice = int(entry.get("choice", -1))
		station.capstone = int(entry.get("capstone", -1))
		var saved_state: Variant = entry.get("state", {})
		station.state = (saved_state as Dictionary).duplicate(true) if saved_state is Dictionary else {}
		if entry.has("meal_slot_locked"):
			station.meal_slot_locked = bool(entry["meal_slot_locked"])
		else:
			has_saved_locks = false
	if not has_saved_locks:
		_roll_meal_slot_locks()
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
