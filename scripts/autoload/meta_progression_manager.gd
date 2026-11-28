extends Node

## Persistent meta progression: lifetime stats, kept in the active profile (ProfileManager).

const SAVE_FILE := preload("res://scripts/helpers/atomic_save_file.gd")
const SAVE_FILE_NAME := "lifetime_stats.save"

var _loaded: bool = false
var _lifetime_stats: Dictionary = {}


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not SAVE_FILE.has_readable(_save_path()):
		_init_defaults()
		return
	var data := SAVE_FILE.read_var_dictionary(_save_path())
	if data.is_empty():
		_init_defaults()
		return
	_apply_save_data(data)


## ProfileManager switched or cleared the profile.
func reload() -> void:
	_loaded = false
	ensure_loaded()


func _save_path() -> String:
	return ProfileManager.path(SAVE_FILE_NAME)


## Read-only copy of lifetime counters for the Stats screen.
func get_lifetime_stats_snapshot() -> Dictionary:
	ensure_loaded()
	return _lifetime_stats.duplicate(true)


func save() -> void:
	var data := {
		"version": 1,
		"lifetime_stats": _lifetime_stats.duplicate(),
	}
	if not SAVE_FILE.write_var(_save_path(), data):
		push_error("MetaProgressionManager: failed to write profile save")


func add_lifetime_triggers(amount: int) -> void:
	_add_stat("total_triggers", amount)


func _add_stat(key: String, amount: int) -> void:
	if amount <= 0 or RunRng.is_unlock_progress_disabled():
		return
	_lifetime_stats[key] = int(_lifetime_stats.get(key, 0)) + amount


func record_run_snapshot(snapshot: Dictionary) -> void:
	if RunRng.is_unlock_progress_disabled():
		return

	var is_win := bool(snapshot.get("is_win", false))
	if is_win:
		_lifetime_stats["wins"] = int(_lifetime_stats.get("wins", 0)) + 1
	else:
		_lifetime_stats["losses"] = int(_lifetime_stats.get("losses", 0)) + 1
	_lifetime_stats["runs_completed"] = int(_lifetime_stats.get("runs_completed", 0)) + 1

	_lifetime_stats["peak_gold_held"] = maxi(
		int(_lifetime_stats.get("peak_gold_held", 0)),
		int(snapshot.get("peak_gold_held", 0))
	)
	_lifetime_stats["peak_gold_earned_in_run"] = maxi(
		int(_lifetime_stats.get("peak_gold_earned_in_run", 0)),
		int(snapshot.get("gold_earned", 0))
	)
	_lifetime_stats["peak_segment_score_single_turn"] = maxi(
		int(_lifetime_stats.get("peak_segment_score_single_turn", 0)),
		int(snapshot.get("peak_segment_score_single_turn", 0))
	)
	_lifetime_stats["peak_triggers_single_turn"] = maxi(
		int(_lifetime_stats.get("peak_triggers_single_turn", 0)),
		int(snapshot.get("peak_triggers_single_turn", 0))
	)
	if is_win:
		var win_difficulty := int(snapshot.get("difficulty", 0)) + 1
		_lifetime_stats["highest_win_difficulty"] = maxi(
			int(_lifetime_stats.get("highest_win_difficulty", 0)),
			win_difficulty
		)
	save()
	ProfileManager.refresh_summary()


func _init_defaults() -> void:
	_lifetime_stats = {
		"total_triggers": 0,
		"wins": 0,
		"losses": 0,
		"runs_completed": 0,
		"peak_gold_held": 0,
		"peak_gold_earned_in_run": 0,
		"peak_segment_score_single_turn": 0,
		"peak_triggers_single_turn": 0,
	}


func _apply_save_data(data: Dictionary) -> void:
	_lifetime_stats = data.get("lifetime_stats", {}).duplicate(true)
