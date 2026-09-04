extends Node

## Append-only archive of finished runs for the Stats Past Runs tab.
## Separate from the mid-run resume save and from lifetime meta aggregates.

const SAVE_FILE := preload("res://scripts/helpers/atomic_save_file.gd")
const SAVE_PATH := "user://run_history.json"
const SAVE_VERSION := 1
const MAX_ENTRIES := 50
const HEX_MAP_GROUP := "hex_map_group"

var _entries: Array = []
var _loaded := false
## Victory archives when the panel opens and again on Main Menu. Keep one write per run.
var _archived_this_run := false


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not SAVE_FILE.has_readable(SAVE_PATH):
		_entries = []
		return
	var data := SAVE_FILE.read_json_dictionary(SAVE_PATH)
	if data.is_empty():
		_entries = []
		return
	_entries = data.get("entries", [])
	if _entries is not Array:
		_entries = []


## Call when a fresh run begins so a later end can archive once.
func notify_run_started() -> void:
	_archived_this_run = false


func get_entries() -> Array:
	ensure_loaded()
	return _entries.duplicate(true)


func get_entry_count() -> int:
	ensure_loaded()
	return _entries.size()


func clear() -> void:
	_entries = []
	_archived_this_run = false
	SAVE_FILE.delete_all(SAVE_PATH)


## Snapshot the live board and run totals into history. Safe to call twice in one run.
func archive_finished_run(is_win: bool) -> void:
	if _archived_this_run:
		return
	_archived_this_run = true
	ensure_loaded()

	var character_id := ""
	if GameManager.selected_character != null:
		character_id = GameManager.selected_character.id

	var snapshot := GameManager.build_run_snapshot(is_win)
	var entry := {
		"ended_at": int(Time.get_unix_time_from_system()),
		"is_win": is_win,
		"character_id": character_id,
		"difficulty": int(GameManager.selected_difficulty),
		# Match the Day value shown on victory / game-over screens.
		"rounds_completed": GameManager.current_round,
		"seed": RunRng.get_display_seed(),
		"is_seeded_run": RunRng.is_seeded_run(),
		"highest_round_score": GameManager.highest_round_score,
		"gold_earned": GoldManager.total_earned_this_run,
		"card_triggers": GameManager.total_rune_activations,
		"peak_gold_held": snapshot.get("peak_gold_held", 0),
		"board": _capture_board_snapshot(),
	}
	_entries.push_front(entry)
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_back()
	_save()


## Slim board for the Past Runs preview. card_id plus hex coords, not live card state.
func _capture_board_snapshot() -> Dictionary:
	var tile_map := _find_tile_map()
	if tile_map == null:
		return {"placed": [], "disabled_coords": []}

	var map_state: Dictionary = tile_map.capture_map_state()
	var placed: Array = []
	for entry: Variant in map_state.get("placed_spot_cards", []):
		if entry is not Dictionary:
			continue
		var card_id := String(entry.get("card_id", ""))
		var coords := _coords_pair(entry.get("coords", []))
		if card_id.is_empty() or coords.is_empty():
			continue
		placed.append({
			"card_id": card_id,
			"coords": coords,
		})

	var disabled: Array = []
	for coords_data: Variant in map_state.get("disabled_coords", []):
		var coords := _coords_pair(coords_data)
		if coords.is_empty():
			continue
		disabled.append(coords)

	return {
		"placed": placed,
		"disabled_coords": disabled,
	}


func _coords_pair(coords_data: Variant) -> Array:
	if coords_data is not Array or coords_data.size() < 2:
		return []
	return [int(coords_data[0]), int(coords_data[1])]


func _find_tile_map() -> HexTileMap:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(HEX_MAP_GROUP) as HexTileMap


func _save() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"entries": _entries,
	}
	if not SAVE_FILE.write_text(SAVE_PATH, JSON.stringify(payload)):
		push_error("RunHistoryManager: failed to write run history")
