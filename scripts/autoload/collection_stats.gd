extends Node

## Lifetime Collection stats, kept in their own file (STATS_PATH), apart from the run save:
## how often the player picked each card, Technique and Condiment, wins with them, Station types
## set and won with, Chef runs and wins, Meal serves and the Story / Fun facts unlocks they drive.
##
## During a run, counts gather in _run (pending) and travel inside the run save, so a run that is
## continued later or abandoned from the menu still counts. They are merged into the lifetime file
## once, when the run ends: won, lost or abandoned. A crash or quit loses only what came after the
## last checkpoint. The playtest bot, fuzz runs and CI never count or write (see _is_tracking).

const STATS_PATH := "user://collection_stats.json"
const SAVE_FILE := preload("res://scripts/helpers/atomic_save_file.gd")
const VERSION := 1

## Lifetime serves of a Meal that unlock its Story and its Fun facts.
const STORY_UNLOCK_SERVES := 30
const FACTS_UNLOCK_SERVES := 50

## Pick keys in _run["picked"] are "<group>:<id>".
const GROUP_CARD := "cards"
const GROUP_TECHNIQUE := "techniques"
const GROUP_CONDIMENT := "condiments"

var _lifetime: Dictionary = {}
var _loaded := false
## This run's pending counts. Keys: picked, served, set (Dictionary id -> count), seen_meals
## (Dictionary id -> true) and, filled by capture_run_state, final (what the run holds now).
var _run: Dictionary = {}
var _finished_this_run := false


func _ready() -> void:
	_run = _empty_run()
	EventBus.meal_fired.connect(_on_meal_fired)
	EventBus.station_type_changed.connect(_on_station_type_changed)
	EventBus.turn_started.connect(_note_deck_meals)


#region Reading (Collection screen)

## {"picked", "wins", "final_runs"} for a card, Technique or Condiment id. group is GROUP_*.
func get_pick_stats(group: String, id: String) -> Dictionary:
	var entry := _entry(group, id)
	return {
		"picked": int(entry.get("picked", 0)),
		"wins": int(entry.get("wins", 0)),
		"final_runs": int(entry.get("final_runs", 0)),
	}


## {"served", "story", "facts", "discovered"} for a Meal id.
func get_meal_stats(meal_id: String) -> Dictionary:
	var entry := _entry("meals", meal_id)
	return {
		"served": int(entry.get("served", 0)),
		"story": bool(entry.get("story", false)),
		"facts": bool(entry.get("facts", false)),
		"discovered": bool(entry.get("discovered", false)),
	}


## {"set", "wins"} for a Station type id.
func get_station_stats(station_id: String) -> Dictionary:
	var entry := _entry("stations", station_id)
	return {"set": int(entry.get("set", 0)), "wins": int(entry.get("wins", 0))}


## {"runs", "wins", "best_day", "highest_difficulty_won"} for a Chef id. highest_difficulty_won is
## a Difficulty.Level index, -1 when never won.
func get_chef_stats(chef_id: String) -> Dictionary:
	var entry := _entry("chefs", chef_id)
	return {
		"runs": int(entry.get("runs", 0)),
		"wins": int(entry.get("wins", 0)),
		"best_day": int(entry.get("best_day", 0)),
		"highest_difficulty_won": int(entry.get("highest_difficulty_won", -1)),
	}

#endregion


#region Tracking during a run

func reset_for_new_run() -> void:
	_run = _empty_run()
	_finished_this_run = false


## A card, Technique or Condiment the player chose to take (Merchant buy, pack pick, card pick).
func record_pick(group: String, id: String) -> void:
	if not _is_tracking() or id.is_empty():
		return
	_increment(_run["picked"], "%s:%s" % [group, id])


## Any card joining the deck. Meals count as discovered once they have been in the deck.
func record_deck_card(card: TileCard) -> void:
	if card is MealCard and _is_tracking():
		(_run["seen_meals"] as Dictionary)[card.id] = true


func _on_meal_fired(meal: MealCard, served: bool) -> void:
	if served and meal != null and _is_tracking():
		_increment(_run["served"], meal.id)


func _on_station_type_changed(_segment_index: int, type_id: String) -> void:
	if type_id.is_empty() or not _is_tracking() or RunSaveManager.is_restoring():
		return
	_increment(_run["set"], type_id)


## The starting deck never goes through gain_card, so the deck is checked each Hour too.
func _note_deck_meals() -> void:
	if not _is_tracking():
		return
	for card: TileCard in DeckManager.all_cards():
		record_deck_card(card)


## Run save hook (RunSaveManager run state owner).
func capture_run_state() -> Dictionary:
	var state := _run.duplicate(true)
	state["final"] = _capture_final()
	return state


func apply_run_state(state: Dictionary) -> void:
	_run = _empty_run()
	for key: String in ["picked", "served", "set", "seen_meals"]:
		if state.get(key) is Dictionary:
			_run[key] = (state[key] as Dictionary).duplicate(true)
	_finished_this_run = false

#endregion


#region Run end

## Merges the live run into the lifetime stats and writes them. Safe to call more than once a run
## (victory, then Main Menu).
func finish_run(is_win: bool) -> void:
	if _finished_this_run or not _is_tracking():
		return
	_finished_this_run = true
	_note_deck_meals()
	var chef_id := GameManager.selected_chef.id if GameManager.selected_chef != null else ""
	_merge(_run, _capture_final(), chef_id, is_win, GameManager.current_round, int(GameManager.selected_difficulty))


## An abandoned run, from its resume save: counts as a run for the Chef, never as a win.
func finish_abandoned_run(save_payload: Dictionary) -> void:
	if not _is_writable():
		return
	var state: Dictionary = save_payload.get("collection_stats", {})
	var game_state: Dictionary = save_payload.get("game_manager", {})
	var final: Dictionary = state.get("final", {}) if state.get("final") is Dictionary else {}
	_merge(state, final, String(save_payload.get("chef_id", "")), false,
		int(game_state.get("current_round", 1)), int(save_payload.get("difficulty", 0)))


func _merge(run: Dictionary, final: Dictionary, chef_id: String, is_win: bool, day: int, difficulty: int) -> void:
	_ensure_loaded()
	var picked: Dictionary = run.get("picked", {})
	for key: String in picked:
		var parts := key.split(":", true, 1)
		if parts.size() == 2:
			_add(_entry_for_write(parts[0], parts[1]), "picked", int(picked[key]))
	var served: Dictionary = run.get("served", {})
	for meal_id: String in served:
		var meal := _entry_for_write("meals", meal_id)
		_add(meal, "served", int(served[meal_id]))
		# Unlocks are stored, so a later threshold change or reset can't lock them again.
		if int(meal["served"]) >= STORY_UNLOCK_SERVES:
			meal["story"] = true
		if int(meal["served"]) >= FACTS_UNLOCK_SERVES:
			meal["facts"] = true
	var seen: Dictionary = run.get("seen_meals", {})
	for meal_id: String in seen:
		_entry_for_write("meals", meal_id)["discovered"] = true
	var station_sets: Dictionary = run.get("set", {})
	for station_id: String in station_sets:
		_add(_entry_for_write("stations", station_id), "set", int(station_sets[station_id]))
	# What the run ended with: a run for each, and a win when the run was won.
	for group: String in [GROUP_CARD, GROUP_TECHNIQUE, GROUP_CONDIMENT]:
		for id: String in _unique(final.get(group, [])):
			var entry := _entry_for_write(group, id)
			_add(entry, "final_runs", 1)
			if is_win:
				_add(entry, "wins", 1)
	if is_win:
		for station_id: String in _unique(final.get("stations", [])):
			_add(_entry_for_write("stations", station_id), "wins", 1)
	if not chef_id.is_empty():
		var chef := _entry_for_write("chefs", chef_id)
		_add(chef, "runs", 1)
		chef["best_day"] = maxi(int(chef.get("best_day", 0)), day)
		if is_win:
			_add(chef, "wins", 1)
			chef["highest_difficulty_won"] = maxi(int(chef.get("highest_difficulty_won", -1)), difficulty)
	_save()


## Card, Technique, Condiment and Station type ids the run holds right now.
func _capture_final() -> Dictionary:
	var cards: Array[String] = []
	for card: TileCard in DeckManager.all_cards():
		cards.append(card.id)
	var techniques: Array[String] = []
	for slot in StaffManager.SLOT_COUNT:
		var staff: StaffCard = StaffManager.slots[slot]
		if staff != null:
			techniques.append(staff.id)
	var condiments: Array[String] = []
	for condiment: Condiment in CondimentManager.belt:
		if condiment != null:
			condiments.append(condiment.id)
	var stations: Array[String] = []
	for segment_index in StationManager.get_station_count():
		var type_id := StationManager.get_station_type_id(segment_index)
		if not type_id.is_empty():
			stations.append(type_id)
	return {
		GROUP_CARD: _unique(cards),
		GROUP_TECHNIQUE: _unique(techniques),
		GROUP_CONDIMENT: _unique(condiments),
		"stations": _unique(stations),
	}

#endregion


#region Storage

## Real players only: the playtest bot and fuzz runs set skip_presentation, and CI runs headless.
func _is_tracking() -> bool:
	return _is_writable() and not GameManager.skip_presentation


func _is_writable() -> bool:
	return DisplayServer.get_name() != "headless"


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var data := SAVE_FILE.read_json_dictionary(STATS_PATH) if SAVE_FILE.has_readable(STATS_PATH) else {}
	_lifetime = data if not data.is_empty() else {"version": VERSION}


func _save() -> void:
	_lifetime["version"] = VERSION
	if not SAVE_FILE.write_text(STATS_PATH, JSON.stringify(_lifetime, "\t")):
		push_error("CollectionStats: failed to write %s." % STATS_PATH)


func _entry(group: String, id: String) -> Dictionary:
	_ensure_loaded()
	var bucket: Variant = _lifetime.get(group)
	if bucket is Dictionary and (bucket as Dictionary).get(id) is Dictionary:
		return (bucket as Dictionary)[id]
	return {}


## Ids from removed content stay in the file. The Collection never asks for them.
func _entry_for_write(group: String, id: String) -> Dictionary:
	if not _lifetime.get(group) is Dictionary:
		_lifetime[group] = {}
	var bucket: Dictionary = _lifetime[group]
	if not bucket.get(id) is Dictionary:
		bucket[id] = {}
	return bucket[id]


func _empty_run() -> Dictionary:
	return {"picked": {}, "served": {}, "set": {}, "seen_meals": {}}


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _add(entry: Dictionary, key: String, amount: int) -> void:
	entry[key] = int(entry.get(key, 0)) + amount


func _unique(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value: Variant in values:
			var text := String(value)
			if not text.is_empty() and text not in result:
				result.append(text)
	return result

#endregion
