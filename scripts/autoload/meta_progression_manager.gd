extends Node

## Persistent meta progression: lifetime stats and per-layout XP.

const SAVE_FILE := preload("res://scripts/helpers/atomic_save_file.gd")
const SAVE_PATH := "user://player_profile.save"
## Cumulative XP to reach layout levels 1 through 9.
## A full win grants about 12 XP (9 rounds + 3 bonus). One win should reach level 2 only.
const LAYOUT_LEVEL_XP: Array[int] = [0, 10, 30, 55, 80, 110, 140, 170, 200]

var _loaded: bool = false
var _lifetime_stats: Dictionary = {}
var _layout_xp: Dictionary = {}


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not SAVE_FILE.has_readable(SAVE_PATH):
		_init_defaults()
		return
	var data := SAVE_FILE.read_var_dictionary(SAVE_PATH)
	if data.is_empty():
		_init_defaults()
		return
	_apply_save_data(data)


## Read-only copy of lifetime counters for the Stats screen.
func get_lifetime_stats_snapshot() -> Dictionary:
	ensure_loaded()
	return _lifetime_stats.duplicate(true)


## Wipes layout XP and lifetime stats back to a fresh profile.
func reset_progression() -> void:
	SAVE_FILE.delete_all(SAVE_PATH)
	_init_defaults()
	save()


func save() -> void:
	var data := {
		"version": 1,
		"lifetime_stats": _lifetime_stats.duplicate(),
		"layout_xp": _layout_xp.duplicate(),
	}
	if not SAVE_FILE.write_var(SAVE_PATH, data):
		push_error("MetaProgressionManager: failed to write profile save")


func get_layout_xp_for_next_level(layout_id: String) -> int:
	var level := get_layout_level(layout_id)
	if level >= LAYOUT_LEVEL_XP.size():
		return LAYOUT_LEVEL_XP[LAYOUT_LEVEL_XP.size() - 1]
	return LAYOUT_LEVEL_XP[level]


func get_max_layout_level() -> int:
	return LAYOUT_LEVEL_XP.size()


func get_layout_level_for_xp(xp: int) -> int:
	var level := 1
	for i in range(LAYOUT_LEVEL_XP.size()):
		if xp >= LAYOUT_LEVEL_XP[i]:
			level = i + 1
	return level


## XP granted by a finished run. Seeded runs that disable unlocks grant none.
func get_layout_xp_gain_from_snapshot(snapshot: Dictionary) -> int:
	if RunRng.is_unlock_progress_disabled():
		return 0
	return _compute_layout_xp_gain(snapshot)


## Fill amount inside the current layout level, used by the end-of-run XP bar.
func get_layout_level_progress(xp: int) -> Dictionary:
	var level := get_layout_level_for_xp(xp)
	var max_level := get_max_layout_level()
	var floor_index := mini(level - 1, LAYOUT_LEVEL_XP.size() - 1)
	var floor_xp := LAYOUT_LEVEL_XP[floor_index]
	if level >= max_level:
		return {
			"level": max_level,
			"is_max": true,
			"xp_into_level": 0,
			"xp_for_level": 1,
			"ratio": 1.0,
			"total_xp": xp,
			"next_total_xp": floor_xp,
		}
	var next_xp := LAYOUT_LEVEL_XP[level]
	var span := maxi(1, next_xp - floor_xp)
	var into := clampi(xp - floor_xp, 0, span)
	return {
		"level": level,
		"is_max": false,
		"xp_into_level": into,
		"xp_for_level": span,
		"ratio": float(into) / float(span),
		"total_xp": xp,
		"next_total_xp": next_xp,
	}


func add_lifetime_triggers(amount: int) -> void:
	_add_stat("total_triggers", amount)


func get_layout_xp(layout_id: String) -> int:
	return int(_layout_xp.get(layout_id, 0))


func get_layout_level(layout_id: String) -> int:
	return get_layout_level_for_xp(get_layout_xp(layout_id))


func _compute_layout_xp_gain(snapshot: Dictionary) -> int:
	# Completed rounds grant 1 XP each. A win adds a flat bonus on top.
	var xp_gain := int(snapshot.get("rounds_completed", 0))
	if bool(snapshot.get("is_win", false)):
		xp_gain += 3
	return maxi(0, xp_gain)


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

	var layout_id := String(snapshot.get("character_id", ""))
	if not layout_id.is_empty():
		_layout_xp[layout_id] = get_layout_xp(layout_id) + _compute_layout_xp_gain(snapshot)

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
	_layout_xp.clear()


func _apply_save_data(data: Dictionary) -> void:
	_lifetime_stats = data.get("lifetime_stats", {}).duplicate(true)
	_layout_xp = data.get("layout_xp", {}).duplicate(true)
