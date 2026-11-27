extends Node


# Manages Day events on Days 3, 6 and 9, then every 3 Days in Endless Mode. The Day 3, 6 and 9
# events are picked at run start, all different. Endless Mode Days roll from the Day 9 pool.
# Design: the project doc claude/event-rework-design.md (Nov 26, 2026). Numbers untuned unless noted.

## Values are saved in run saves, so each event keeps its number. Gaps are removed events
## (1 Rush Hour, Nov 2026). Renamed events kept their numbers: Fading Sector -> Fading Station,
## Short Staffed (Rusty Hands) -> Shift Swap, Austerity -> Wages Due, Sealed Hexes -> Sealed Plates,
## Raised Stakes -> Full Service.
enum Type {
	BLACKOUT = 0,
	FADING_STATION = 3,
	SHIFT_SWAP = 6,
	WAGES_DUE = 7,
	SEALED_PLATES = 8,
	FULL_SERVICE = 10,
	REVERSE_SERVICE = 11,
	OUT_OF_STOCK = 12,
	EIGHTY_SIXED = 13,
	NO_REPEATS = 14,
	BAD_REVIEW = 15,
}

const EVENT_ROUNDS: Array[int] = [3, 6, ScoreProgression.RUN_LENGTH_ROUNDS]
const ANY_EVENT_ROUND: Array[int] = [3, 6, ScoreProgression.RUN_LENGTH_ROUNDS]
const EARLY_EVENT_ROUNDS: Array[int] = [3, 6]
const LATE_EVENT_ROUNDS: Array[int] = [6, ScoreProgression.RUN_LENGTH_ROUNDS]
const FIRST_EVENT_ROUND: Array[int] = [3]
const FINAL_EVENT_ROUND: Array[int] = [ScoreProgression.RUN_LENGTH_ROUNDS]
## Endless Mode: an event every this many Days after the last standard event Day (12, 15, ...),
## rolled from the Day 9 pool, never the same event twice in a row (user, Nov 26: any Day 9 event).
const ENDLESS_EVENT_EVERY := 3

## Blackout: cards on the cooking Station that go dark each Turn.
const BLACKOUT_COUNT := 2
## Wages Due: Gold lost at the start of every Turn (user, Nov 26). Gold never goes below 0.
const WAGES_PER_TURN := 4
## Full Service: a Turn under this share of the Day's target scores nothing (user, Nov 27: 20%).
const FULL_SERVICE_SHARE := 0.20
## Out of Stock: Ingredient kinds not drawn this Day (user, Nov 26: 2).
const OUT_OF_STOCK_KIND_COUNT := 2
## 86'd: the most-served Meals on the board that can't be served this Day.
const EIGHTY_SIXED_COUNT := 2
## Bad Review: the goal has to be met by the end of this Turn to keep the stars.
const BAD_REVIEW_LAST_TURN := 3
## Board tint for the card Bad Review puts at stake.
const BAD_REVIEW_MODULATE := Color(1.0, 0.62, 0.55, 1.0)

const ALL_EVENTS: Array[Type] = [
	Type.BLACKOUT,
	Type.FADING_STATION,
	Type.SHIFT_SWAP,
	Type.WAGES_DUE,
	Type.SEALED_PLATES,
	Type.FULL_SERVICE,
	Type.REVERSE_SERVICE,
	Type.OUT_OF_STOCK,
	Type.EIGHTY_SIXED,
	Type.NO_REPEATS,
	Type.BAD_REVIEW,
]

const EVENT_INFO := {
	Type.BLACKOUT: {
		"name": "Blackout",
		"description": "Every Turn, 2 cards on the Station that cooks that Turn are disabled.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.FADING_STATION: {
		"name": "Fading Station",
		"description": "One Station has its Ingredient output halved for the whole Day.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.SHIFT_SWAP: {
		"name": "Shift Swap",
		"description": "Every Technique moves one seat down for the Day. The bottom one moves to the top. Techniques can't be moved until the Day ends.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.WAGES_DUE: {
		"name": "Wages Due",
		"description": "Lose 4 Gold at the start of every Turn.",
		"rounds": EARLY_EVENT_ROUNDS,
	},
	Type.SEALED_PLATES: {
		"name": "Sealed Plates",
		"description": "One Meal slot on each Station is sealed for the Day. A Meal on it isn't served.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.FULL_SERVICE: {
		"name": "Full Service",
		"description": "A Turn that scores less than 20% of the Day's target scores nothing.",
		"rounds": FINAL_EVENT_ROUND,
	},
	Type.REVERSE_SERVICE: {
		"name": "Reverse Service",
		"description": "Stations cook from the bottom up.",
		"rounds": FIRST_EVENT_ROUND,
	},
	Type.OUT_OF_STOCK: {
		"name": "Out of Stock",
		"description": "Two Ingredient kinds aren't drawn this Day.",
		"rounds": ANY_EVENT_ROUND,
	},
	Type.EIGHTY_SIXED: {
		"name": "86'd",
		"description": "Your 2 most-served Meals on the board can't be served this Day.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.NO_REPEATS: {
		"name": "No Repeats",
		"description": "A Meal that is on more than one Station scores nothing this Day.",
		"rounds": LATE_EVENT_ROUNDS,
	},
	Type.BAD_REVIEW: {
		"name": "Bad Review",
		"description": "Reach the target by the end of Turn 3, or your highest-starred card loses all its stars.",
		"rounds": EARLY_EVENT_ROUNDS,
	},
}

## One event per entry in EVENT_ROUNDS, chosen at run start.
var scheduled_events: Array[Type] = []
## Active event for the current round, -1 when no event is running.
var active_event: int = -1

## Fading Station: the Station whose Ingredient output is halved, -1 when none.
var _halved_segment_index := -1
## Sealed Plates: spots sealed for the Day (Meal slots, or a regular spot where the slot is locked).
var _sealed_coords: Array[Vector2i] = []
## Out of Stock: Ingredient kinds not drawn this Day.
var _out_of_stock_kinds: Array[StringName] = []
## 86'd: Meal ids that can't be served this Day.
var _eighty_sixed_ids: Array[String] = []
## Bad Review: the card at stake, and its spot (saves keep the spot).
var _bad_review_card: TileCard = null
var _pending_bad_review_coords := Vector2i(-1, -1)
## Shift Swap: true while the Techniques sit one seat down.
var _shift_swapped := false
## Meal id -> times served this run. 86'd picks from it. What-if Hours are not counted.
var _run_serves: Dictionary = {}
## Endless Mode events, worked out from the run seed on demand. Not saved.
var _endless_cache: Dictionary = {}

## Saved is_active values so player toggles are restored after each turn's blackout.
var _disabled_prior_states: Dictionary = {}
## Blackout spots read from a save. Re-applied once the map has restored its cards.
var _pending_blackout_coords: Array[Vector2i] = []
var _tile_map: HexTileMap = null


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.meal_fired.connect(_on_meal_fired)


# Pick three unique events that are legal for rounds 3, 6, and 9.
func init_run() -> void:
	scheduled_events.clear()
	active_event = -1
	_endless_cache.clear()
	_run_serves.clear()
	_clear_day_state()

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


## A new Day was reached (before the Merchant). Picks what doesn't depend on the Day's board.
func on_round_advanced(new_round: int) -> void:
	_clear_day_state()
	active_event = get_event_for_round(new_round)

	match active_event:
		Type.FADING_STATION:
			_pick_halved_segment()
		Type.SEALED_PLATES:
			_pick_sealed_plates()
		Type.OUT_OF_STOCK:
			_pick_out_of_stock_kinds()

	if active_event == -1:
		EventBus.event_banner_hidden.emit()

	EventBus.event_changed.emit()


## The Day's first Turn is about to start (after the Merchant). Picks what reads the board.
func on_day_started() -> void:
	match active_event:
		Type.SHIFT_SWAP:
			_apply_shift_swap()
		Type.EIGHTY_SIXED:
			_pick_eighty_sixed()
		Type.BAD_REVIEW:
			_pick_bad_review_card()
		Type.FADING_STATION:
			if _halved_segment_index < 0:
				_pick_halved_segment()
	EventBus.event_changed.emit()


## The Day's goal was met. Called before the summary.
func on_day_ended() -> void:
	if active_event == Type.BAD_REVIEW:
		_resolve_bad_review()
	_undo_shift_swap()


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
		return _endless_event_for_round(event_round)
	# Left panel can query before main.gd calls init_run() at run start.
	if round_index >= scheduled_events.size():
		return -1
	return scheduled_events[round_index]


func get_next_event_round() -> int:
	for event_round in EVENT_ROUNDS:
		if event_round > GameManager.current_round:
			return event_round
	var last: int = EVENT_ROUNDS[-1]
	var days_after := GameManager.current_round - last
	return GameManager.current_round + ENDLESS_EVENT_EVERY - posmod(days_after, ENDLESS_EVENT_EVERY)


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
	if allowed.is_empty():
		return ""
	var parts: PackedStringArray = []
	for allowed_round: Variant in allowed:
		parts.append(str(int(allowed_round)))
	var endless := allowed.has(EVENT_ROUNDS[-1])
	if parts.size() == 1:
		return "Day %s%s" % [parts[0], " and Endless" if endless else " only"]
	var days := ", ".join(parts.slice(0, parts.size() - 1))
	if endless:
		return "Days %s, %s and Endless" % [days, parts[-1]]
	return "Days %s and %s" % [days, parts[-1]]


func get_event_name(event_type: int) -> String:
	if event_type == -1:
		return ""
	return CardKeywordGlossary.to_plain(EVENT_INFO[event_type]["name"])


## The event's rules. The active event also names today's picks (Station, kinds, Meals, card).
func get_event_description(event_type: int) -> String:
	if event_type == -1:
		return ""
	var text := CardKeywordGlossary.to_plain(EVENT_INFO[event_type]["description"])
	if event_type == active_event:
		var detail := _active_detail()
		if not detail.is_empty():
			text += "\n" + detail
	return text


func get_active_event_name() -> String:
	return get_event_name(active_event)


func get_max_turns_per_round() -> int:
	return GameManager.MAX_TURNS_PER_ROUND


## Pack size for the current offer.
func get_cards_pack_size(_is_round_reward: Variant = null) -> int:
	return GameManager.CARDS_PACK_SIZE


func get_producer_output_multiplier(tile: Hex) -> float:
	if active_event != Type.FADING_STATION or _halved_segment_index < 0:
		return 1.0
	if tile.active_tile_card == null or not TileCard.is_producer_type(tile.active_tile_card.type):
		return 1.0

	var tile_map := _get_tile_map()
	if tile_map == null:
		return 1.0
	if tile_map.get_segment_index(tile.coordinates) != _halved_segment_index:
		return 1.0
	return 0.5


## Full Service. A Turn under FULL_SERVICE_SHARE of the Day's target scores nothing.
func apply_turn_score_rule(score: int) -> int:
	if active_event != Type.FULL_SERVICE:
		return score
	return score if score >= get_full_service_threshold() else 0


func get_full_service_threshold() -> int:
	return int(ceil(float(GameManager.required_score) * FULL_SERVICE_SHARE))


## Reverse Service. Stations cook bottom to top (HexTileMap.get_cooking_segment_for_hour).
func is_cooking_reversed() -> bool:
	return active_event == Type.REVERSE_SERVICE


## Shift Swap. Techniques stay in their moved seats until the Day ends.
func is_staff_locked() -> bool:
	return _shift_swapped


## Out of Stock. DeckManager leaves these cards in the draw pile.
func is_card_out_of_stock(card: TileCard) -> bool:
	if active_event != Type.OUT_OF_STOCK or card == null:
		return false
	if card.type != TileCard.TileCardType.INGREDIENT:
		return false
	for tag: StringName in card.ingredient_tags:
		if _out_of_stock_kinds.has(tag):
			return true
	return false


## Sealed Plates. Sealed spots take no new card.
func is_hex_sealed(coords: Vector2i) -> bool:
	return _sealed_coords.has(coords)


## True when today's event stops the card on hex from triggering, scoring or being served:
## a sealed spot (Sealed Plates), an 86'd Meal, or a Meal on more than one Station (No Repeats).
func is_card_blocked(hex: Hex) -> bool:
	if active_event == -1 or hex == null or hex.active_tile_card == null:
		return false
	match active_event:
		Type.SEALED_PLATES:
			return _sealed_coords.has(hex.coordinates)
		Type.EIGHTY_SIXED:
			var card := hex.active_tile_card
			return card.type == TileCard.TileCardType.MEAL and _eighty_sixed_ids.has(card.id)
		Type.NO_REPEATS:
			return _is_repeated_meal(hex)
	return false


func get_out_of_stock_kinds() -> Array[StringName]:
	return _out_of_stock_kinds.duplicate()


func get_eighty_sixed_ids() -> Array[String]:
	return _eighty_sixed_ids.duplicate()


func get_halved_segment_index() -> int:
	return _halved_segment_index


func _on_turn_started() -> void:
	match active_event:
		Type.BLACKOUT:
			_apply_blackout()
		Type.WAGES_DUE:
			_charge_wages()
		Type.FADING_STATION:
			_apply_fading_station_visuals()
	_refresh_event_card_visuals()


func _on_meal_fired(meal: MealCard, served: bool) -> void:
	if not served or meal == null or GameManager.playtest_simulating_hour:
		return
	_run_serves[meal.id] = int(_run_serves.get(meal.id, 0)) + 1


## Clears every per-Day pick and visual.
func _clear_day_state() -> void:
	_restore_event_disabled_runes()
	_pending_blackout_coords.clear()
	_clear_fading_station_visuals()
	_clear_sealed_hexes()
	_undo_shift_swap()
	_out_of_stock_kinds.clear()
	_eighty_sixed_ids.clear()
	_bad_review_card = null
	_pending_bad_review_coords = Vector2i(-1, -1)
	_clear_event_card_modulates()


#region Blackout

## The Turn about to be played. turn_started fires before the finished Turn is counted.
func _upcoming_turn_number() -> int:
	return GameManager.get_turn_number() + (1 if GameManager.is_processing_turn else 0)


func _apply_blackout() -> void:
	_restore_event_disabled_runes()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	var segment := tile_map.get_cooking_segment_for_hour(_upcoming_turn_number())
	var candidates: Array[Hex] = []
	for hex: Hex in tile_map.get_hexes_in_segment(segment):
		if hex.active_tile_card != null:
			candidates.append(hex)
	candidates.sort_custom(_hex_before)
	var rng := RunRng.create_rng("event:blackout:r%d:s%d" % [
		GameManager.current_round,
		GameManager.turn_stamp,
	])
	RunRng.shuffle_with(rng, candidates)

	for i in mini(BLACKOUT_COUNT, candidates.size()):
		var hex := candidates[i]
		var rune := hex.active_tile_card
		_disabled_prior_states[rune] = rune.is_active
		rune.is_active = false
		hex.refresh_own_visuals()
	tile_map.refresh_board_output_chips()


## is_active as it was before Blackout touched the card. Saves write this, so a load never
## inherits a Blackout that would otherwise never be lifted.
func get_saved_is_active(card: TileCard) -> bool:
	if _disabled_prior_states.has(card):
		return bool(_disabled_prior_states[card])
	return card.is_active


func _restore_event_disabled_runes() -> void:
	var tile_map := _get_tile_map()
	for rune: TileCard in _disabled_prior_states:
		if is_instance_valid(rune):
			rune.is_active = _disabled_prior_states[rune]
			if tile_map != null:
				var hex := tile_map.get_hex_for_tile_card(rune)
				if hex != null:
					hex.refresh_own_visuals()
	_disabled_prior_states.clear()
	if tile_map != null:
		tile_map.refresh_board_output_chips()


## Darkens the cards a save recorded as blacked out, remembering their real state.
func _reapply_saved_blackout() -> void:
	if _pending_blackout_coords.is_empty():
		return
	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	if active_event == Type.BLACKOUT:
		for coords: Vector2i in _pending_blackout_coords:
			if not tile_map.map_data.has(coords):
				continue
			var hex: Hex = tile_map.map_data[coords]
			var rune := hex.active_tile_card
			if rune == null:
				continue
			_disabled_prior_states[rune] = rune.is_active
			rune.is_active = false
			hex.refresh_own_visuals()
		tile_map.refresh_board_output_chips()
	_pending_blackout_coords.clear()

#endregion


#region Fading Station

func _pick_halved_segment() -> void:
	_clear_fading_station_visuals()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	var segment_count := tile_map.get_segment_count()
	if segment_count <= 0:
		return

	_halved_segment_index = RunRng.create_rng("event:fading_station:r%d" % GameManager.current_round) \
		.randi() % segment_count
	_apply_fading_station_visuals()


func _apply_fading_station_visuals() -> void:
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


func _clear_fading_station_visuals() -> void:
	_halved_segment_index = -1
	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	tile_map.clear_event_segment_highlight()
	for hex: Hex in tile_map.get_all_hexes_with_runes():
		hex.clear_tile_card_event_modulate()

#endregion


#region Shift Swap

func _apply_shift_swap() -> void:
	if _shift_swapped:
		return
	StaffManager.rotate_slots(1)
	_shift_swapped = true


func _undo_shift_swap() -> void:
	if not _shift_swapped:
		return
	_shift_swapped = false
	StaffManager.rotate_slots(-1)

#endregion


#region Wages Due

func _charge_wages() -> void:
	EconomyManager.lose(mini(WAGES_PER_TURN, EconomyManager.amount))

#endregion


#region Sealed Plates

## Each Station's second Meal slot. Where difficulty already locks it, a random regular spot instead.
func _pick_sealed_plates() -> void:
	_clear_sealed_hexes()

	var tile_map := _get_tile_map()
	if tile_map == null:
		return

	var rng := RunRng.create_rng("event:sealed_plates:r%d" % GameManager.current_round)
	for segment in tile_map.get_segment_count():
		var meal_slots := tile_map.get_meal_slot_coords(segment)
		if meal_slots.size() >= 2 and not StationManager.is_meal_slot_locked(meal_slots[1]):
			_sealed_coords.append(meal_slots[1])
			continue
		var regular: Array[Vector2i] = []
		for hex: Hex in tile_map.get_hexes_in_segment(segment):
			if not tile_map.is_meal_slot(hex.coordinates):
				regular.append(hex.coordinates)
		if regular.is_empty():
			continue
		regular.sort_custom(_coords_before)
		_sealed_coords.append(regular[rng.randi() % regular.size()])
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

#endregion


#region Out of Stock

## Two kinds the deck holds, never both from one Station's setup, so no Station is wiped out.
func _pick_out_of_stock_kinds() -> void:
	_out_of_stock_kinds.clear()

	var held: Array[StringName] = []
	for card: TileCard in DeckManager.all_cards():
		var kind := IngredientKindRules.rule_kind(card)
		if not kind.is_empty() and not held.has(kind):
			held.append(kind)
	var kinds: Array[StringName] = []
	for kind: StringName in IngredientKindRules.RULE_KINDS:
		if held.has(kind):
			kinds.append(kind)

	var groups: Array = []
	var forbidden := _setup_kind_sets()
	_collect_kind_groups(kinds, 0, [], OUT_OF_STOCK_KIND_COUNT, forbidden, groups)
	if groups.is_empty():
		# A thin deck: fall back to one kind.
		_collect_kind_groups(kinds, 0, [], 1, forbidden, groups)
	if groups.is_empty():
		return
	var rng := RunRng.create_rng("event:out_of_stock:r%d" % GameManager.current_round)
	var picked: Array = groups[rng.randi() % groups.size()]
	for kind: Variant in picked:
		_out_of_stock_kinds.append(StringName(kind))


## Every group of size kinds (in RULE_KINDS order) that doesn't hold two kinds from one setup.
func _collect_kind_groups(
	kinds: Array[StringName], start: int, current: Array, size: int, forbidden: Array, out: Array
) -> void:
	if current.size() == size:
		out.append(current.duplicate())
		return
	for i in range(start, kinds.size()):
		var candidate: StringName = kinds[i]
		var clashes := false
		for setup: Variant in forbidden:
			var setup_kinds: Array = setup
			if not setup_kinds.has(candidate):
				continue
			for chosen: Variant in current:
				if setup_kinds.has(chosen):
					clashes = true
		if clashes:
			continue
		current.append(candidate)
		_collect_kind_groups(kinds, i + 1, current, size, forbidden, out)
		current.pop_back()


## The Ingredient kinds each Station type's setup asks for.
func _setup_kind_sets() -> Array:
	var sets: Array = []
	for station_type: StationType in StationManager.get_station_types():
		var kinds: Array = []
		for tag: Variant in station_type.required_counts:
			var kind := StringName(tag)
			if IngredientKindRules.RULE_KINDS.has(kind):
				kinds.append(kind)
		if kinds.size() >= 2:
			sets.append(kinds)
	return sets

#endregion


#region 86'd

func _pick_eighty_sixed() -> void:
	_eighty_sixed_ids.clear()
	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	var ids: Array[String] = []
	for hex: Hex in tile_map.get_all_hexes_with_runes():
		var card := hex.active_tile_card
		if card != null and card.type == TileCard.TileCardType.MEAL and not ids.has(card.id):
			ids.append(card.id)
	ids.sort()
	# Ties go by a seeded shuffle, then the stable sort keeps that order among equals.
	RunRng.shuffle_with(RunRng.create_rng("event:eighty_sixed:r%d" % GameManager.current_round), ids)
	var serves := _run_serves
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(serves.get(a, 0)) > int(serves.get(b, 0))
	)
	for i in mini(EIGHTY_SIXED_COUNT, ids.size()):
		_eighty_sixed_ids.append(ids[i])
	_refresh_event_card_visuals()

#endregion


#region No Repeats

func _is_repeated_meal(hex: Hex) -> bool:
	var card := hex.active_tile_card
	if card == null or card.type != TileCard.TileCardType.MEAL or hex.map == null:
		return false
	var map := hex.map
	var own_segment := map.get_segment_index(hex.coordinates)
	for segment in map.get_segment_count():
		if segment == own_segment:
			continue
		for coords: Vector2i in map.get_meal_slot_coords(segment):
			if not map.map_data.has(coords):
				continue
			var other: Hex = map.map_data[coords]
			if other.active_tile_card != null and other.active_tile_card.id == card.id:
				return true
	return false

#endregion


#region Bad Review

func _pick_bad_review_card() -> void:
	_bad_review_card = null
	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	var best: Array[Hex] = []
	var best_stars := 1
	for hex: Hex in tile_map.get_all_hexes_with_runes():
		var stars := hex.active_tile_card.star_level
		if stars > best_stars:
			best_stars = stars
			best.clear()
		if stars == best_stars and stars > 1:
			best.append(hex)
	if best.is_empty():
		return
	best.sort_custom(_hex_before)
	var rng := RunRng.create_rng("event:bad_review:r%d" % GameManager.current_round)
	_bad_review_card = best[rng.randi() % best.size()].active_tile_card
	_refresh_event_card_visuals()


func _resolve_bad_review() -> void:
	var card := _bad_review_card
	_bad_review_card = null
	if card == null or not is_instance_valid(card):
		return
	if GameManager.get_turn_number() <= BAD_REVIEW_LAST_TURN:
		_clear_event_card_modulates()
		return
	var tile_map := _get_tile_map()
	var hex := tile_map.get_hex_for_tile_card(card) if tile_map != null else null
	if hex == null:
		return
	card.star_level = 1
	hex.clear_tile_card_event_modulate()
	hex.refresh_tile_card_visual_state()

#endregion


#region Board visuals

## Tints 86'd and repeated Meals, sealed cards and the Bad Review card.
func _refresh_event_card_visuals() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	match active_event:
		Type.EIGHTY_SIXED, Type.NO_REPEATS, Type.SEALED_PLATES:
			for hex: Hex in tile_map.get_all_hexes_with_runes():
				if is_card_blocked(hex):
					hex.set_tile_card_event_modulate(Hex.RUNE_INACTIVE_MODULATE)
				else:
					hex.clear_tile_card_event_modulate()
			tile_map.refresh_board_output_chips()
		Type.BAD_REVIEW:
			if _bad_review_card != null and is_instance_valid(_bad_review_card):
				var hex := tile_map.get_hex_for_tile_card(_bad_review_card)
				if hex != null:
					hex.set_tile_card_event_modulate(BAD_REVIEW_MODULATE)


func _clear_event_card_modulates() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null:
		return
	for hex: Hex in tile_map.get_all_hexes_with_runes():
		hex.clear_tile_card_event_modulate()

#endregion


## The active event's picks, as one line for its description.
func _active_detail() -> String:
	match active_event:
		Type.FADING_STATION:
			if _halved_segment_index >= 0:
				return "Today: Station %d." % (_halved_segment_index + 1)
		Type.OUT_OF_STOCK:
			if not _out_of_stock_kinds.is_empty():
				var names: PackedStringArray = []
				for kind: StringName in _out_of_stock_kinds:
					names.append(String(kind).capitalize())
				return "Today: %s." % " and ".join(names)
		Type.EIGHTY_SIXED:
			if not _eighty_sixed_ids.is_empty():
				var names: PackedStringArray = []
				for meal_id: String in _eighty_sixed_ids:
					names.append(_meal_name(meal_id))
				return "Today: %s." % " and ".join(names)
		Type.BAD_REVIEW:
			if _bad_review_card != null and is_instance_valid(_bad_review_card):
				return "At stake: %s (%d stars)." % [_bad_review_card.name, _bad_review_card.star_level]
		Type.FULL_SERVICE:
			return "Each Turn needs at least %d." % get_full_service_threshold()
	return ""


func _meal_name(meal_id: String) -> String:
	var tile_map := _get_tile_map()
	if tile_map != null:
		for hex: Hex in tile_map.get_all_hexes_with_runes():
			if hex.active_tile_card.id == meal_id:
				return hex.active_tile_card.name
	return meal_id


func _endless_event_for_round(event_round: int) -> int:
	var last: int = EVENT_ROUNDS[-1]
	if event_round <= last or (event_round - last) % ENDLESS_EVENT_EVERY != 0:
		return -1
	if _endless_cache.has(event_round):
		return int(_endless_cache[event_round])
	var previous := get_event_for_round(event_round - ENDLESS_EVENT_EVERY)
	var pool: Array[int] = []
	for event_type: Type in ALL_EVENTS:
		if event_type != previous and is_legal_for_round(event_type, last):
			pool.append(event_type)
	var picked := -1
	if not pool.is_empty():
		var rng := RunRng.create_rng("events:endless:r%d" % event_round)
		picked = pool[rng.randi() % pool.size()]
	_endless_cache[event_round] = picked
	return picked


func _unused_legal_types(event_round: int, used: Array) -> Array:
	var available: Array = []
	for event_type in ALL_EVENTS:
		if used.has(event_type):
			continue
		if not is_legal_for_round(event_type, event_round):
			continue
		available.append(event_type)
	return available


static func _hex_before(a: Hex, b: Hex) -> bool:
	return _coords_before(a.coordinates, b.coordinates)


static func _coords_before(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


func _get_tile_map() -> HexTileMap:
	if _tile_map != null and is_instance_valid(_tile_map):
		return _tile_map

	# The board StationManager is bound to. The playtest board isn't in hex_map_group.
	var bound := StationManager.get_board()
	if bound != null and is_instance_valid(bound):
		_tile_map = bound
		return _tile_map
	for node in get_tree().get_nodes_in_group("hex_map_group"):
		_tile_map = node as HexTileMap
		if _tile_map != null:
			return _tile_map
	return null


#region Debug

## Forces an event on the current round and applies its immediate effects.
func debug_activate_event(event_type: int) -> void:
	if not ALL_EVENTS.has(event_type):
		push_warning("EventManager: invalid debug event type %d." % event_type)
		return

	_clear_day_state()
	active_event = event_type
	match active_event:
		Type.FADING_STATION:
			_pick_halved_segment()
		Type.SEALED_PLATES:
			_pick_sealed_plates()
		Type.OUT_OF_STOCK:
			_pick_out_of_stock_kinds()
	on_day_started()
	if active_event == Type.BLACKOUT:
		_apply_blackout()
	_refresh_event_card_visuals()

	EventBus.event_changed.emit()
	EventBus.turn_changed.emit()
	play_reveal()


## Clears any sandbox-forced event and restores normal map visuals.
func debug_clear_event() -> void:
	if active_event == -1:
		return

	_clear_day_state()
	active_event = -1
	EventBus.event_banner_hidden.emit()
	EventBus.event_changed.emit()
	EventBus.turn_changed.emit()

#endregion


func capture_run_state() -> Dictionary:
	var sealed: Array = []
	for coords in _sealed_coords:
		sealed.append([coords.x, coords.y])
	var blackout: Array = []
	var bad_review: Array = []
	var tile_map := _get_tile_map()
	if tile_map != null:
		for rune: TileCard in _disabled_prior_states:
			var hex := tile_map.get_hex_for_tile_card(rune) if is_instance_valid(rune) else null
			if hex != null:
				blackout.append([hex.coordinates.x, hex.coordinates.y])
		if _bad_review_card != null and is_instance_valid(_bad_review_card):
			var target := tile_map.get_hex_for_tile_card(_bad_review_card)
			if target != null:
				bad_review = [target.coordinates.x, target.coordinates.y]
	var kinds: Array = []
	for kind: StringName in _out_of_stock_kinds:
		kinds.append(String(kind))
	return {
		"blackout_coords": blackout,
		"scheduled_events": scheduled_events.duplicate(),
		"active_event": active_event,
		"halved_segment_index": _halved_segment_index,
		"sealed_coords": sealed,
		"out_of_stock_kinds": kinds,
		"eighty_sixed_ids": _eighty_sixed_ids.duplicate(),
		"bad_review_coords": bad_review,
		"shift_swapped": _shift_swapped,
		"run_serves": _run_serves.duplicate(),
	}


func apply_run_state(state: Dictionary) -> void:
	scheduled_events.clear()
	_endless_cache.clear()
	var saved_schedule: Array = state.get("scheduled_events", [])
	for index in saved_schedule.size():
		var saved := int(saved_schedule[index])
		var event_round: int = EVENT_ROUNDS[index] if index < EVENT_ROUNDS.size() else -1
		if event_round == -1:
			break
		if ALL_EVENTS.has(saved) and is_legal_for_round(saved, event_round):
			scheduled_events.append(saved as Type)
			continue
		# A removed event (Rush Hour), or one no longer legal that Day: take the first legal one left.
		var used: Array = []
		used.assign(scheduled_events)
		for later in range(index + 1, saved_schedule.size()):
			used.append(int(saved_schedule[later]))
		var available := _unused_legal_types(event_round, used)
		if not available.is_empty():
			scheduled_events.append(available[0] as Type)

	var saved_active := int(state.get("active_event", -1))
	active_event = saved_active if ALL_EVENTS.has(saved_active) else -1
	# A Day 3/6/9 event replaced above follows its replacement. RunRng restores after this owner,
	# so Endless Days are not worked out here.
	var round_index := EVENT_ROUNDS.find(GameManager.current_round)
	if active_event != -1 and round_index >= 0 and round_index < scheduled_events.size():
		active_event = scheduled_events[round_index]
	_halved_segment_index = int(state.get("halved_segment_index", -1))
	_sealed_coords.clear()
	for coords_data: Variant in state.get("sealed_coords", []):
		if coords_data is not Array or coords_data.size() < 2:
			continue
		_sealed_coords.append(Vector2i(int(coords_data[0]), int(coords_data[1])))
	_disabled_prior_states.clear()
	_pending_blackout_coords.clear()
	for coords_data: Variant in state.get("blackout_coords", []):
		if coords_data is Array and coords_data.size() >= 2:
			_pending_blackout_coords.append(Vector2i(int(coords_data[0]), int(coords_data[1])))
	_out_of_stock_kinds.clear()
	for kind: Variant in state.get("out_of_stock_kinds", []):
		_out_of_stock_kinds.append(StringName(str(kind)))
	_eighty_sixed_ids.clear()
	for meal_id: Variant in state.get("eighty_sixed_ids", []):
		_eighty_sixed_ids.append(str(meal_id))
	_bad_review_card = null
	_pending_bad_review_coords = Vector2i(-1, -1)
	var review: Array = state.get("bad_review_coords", [])
	if review.size() >= 2:
		_pending_bad_review_coords = Vector2i(int(review[0]), int(review[1]))
	# StaffManager restores its slots as saved, already moved.
	_shift_swapped = bool(state.get("shift_swapped", false))
	_run_serves = (state.get("run_serves", {}) as Dictionary).duplicate()
	_tile_map = null


func restore_banner_after_load() -> void:
	# A queued reveal stays queued so the load does not reveal it before the merchant closes.
	if active_event == -1 or RoundFlow.has_armed_event_reveal():
		EventBus.event_banner_hidden.emit()
		return

	EventBus.event_banner_shown.emit(get_active_event_name(), true)


func refresh_event_visuals() -> void:
	_reapply_saved_blackout()
	var tile_map := _get_tile_map()
	if _pending_bad_review_coords.x >= 0 and tile_map != null:
		if tile_map.map_data.has(_pending_bad_review_coords):
			var hex: Hex = tile_map.map_data[_pending_bad_review_coords]
			_bad_review_card = hex.active_tile_card
	_pending_bad_review_coords = Vector2i(-1, -1)

	if active_event == Type.FADING_STATION and _halved_segment_index >= 0:
		_apply_fading_station_visuals()
	elif tile_map != null:
		tile_map.clear_event_segment_highlight()

	if active_event == Type.SEALED_PLATES and not _sealed_coords.is_empty():
		_apply_sealed_overlay()
	elif tile_map != null:
		tile_map.clear_event_sealed_overlay()
	_refresh_event_card_visuals()
