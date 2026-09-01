extends Node

## Persistent meta progression: global passive unlocks and per-character passive sets (A/B/C).

const SAVE_FILE := preload("res://scripts/helpers/atomic_save_file.gd")
const SAVE_PATH := "user://player_profile.save"
const PASSIVES_DIR := "res://resources/segment_passives/"
const LOADOUT_SET_IDS: Array[String] = ["A", "B", "C"]
const RETIRED_PASSIVE_IDS: Array[String] = ["spark_surge", "steady_growth", "power_boost"]
const PASSIVE_ID_MIGRATIONS: Dictionary = {
	"steady_growth": "energy_boost",
	"power_boost": "energy_boost",
	"spark_surge": "spark",
}
const SANDBOX_CHARACTER_ID := "_ui_sandbox"
const SANDBOX_MAX_COPIES := 8
## Cumulative XP to reach layout levels 1 through 9.
## A full win grants about 12 XP (9 rounds + 3 bonus). One win should reach level 2 only.
## Layout-exclusive passive gates sit at levels 3, 6, and 9.
const LAYOUT_LEVEL_XP: Array[int] = [0, 10, 30, 55, 80, 110, 140, 170, 200]

var _loaded: bool = false
var _sandbox_mode: bool = false
var _passives_by_id: Dictionary = {}
var _unlocked_passive_ids: Array[String] = []
var _lifetime_stats: Dictionary = {}
var _layout_xp: Dictionary = {}
var _character_loadouts: Dictionary = {}
var _pending_unlock_reveals: Array[String] = []
var _run_peaks: Dictionary = {}


func _ready() -> void:
	ensure_loaded()
	_load_passive_resources()


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


## Wipes unlocks, layout XP, loadouts, lifetime stats, and pending reveals back to a fresh profile.
func reset_progression() -> void:
	if _sandbox_mode:
		end_ui_sandbox()
	SAVE_FILE.delete_all(SAVE_PATH)
	_init_defaults()
	_grant_starting_unlocks()
	save()


func save() -> void:
	if _sandbox_mode:
		return
	var data := {
		"version": 1,
		"unlocked_passive_ids": _unlocked_passive_ids.duplicate(),
		"lifetime_stats": _lifetime_stats.duplicate(),
		"layout_xp": _layout_xp.duplicate(),
		"character_loadouts": _character_loadouts.duplicate(true),
		"pending_unlock_reveals": _pending_unlock_reveals.duplicate(),
	}
	if not SAVE_FILE.write_var(SAVE_PATH, data):
		push_error("MetaProgressionManager: failed to write profile save")


func get_all_passives_for_character(character_id: String) -> Array[SegmentPassive]:
	var result: Array[SegmentPassive] = []
	for passive_id: String in _passives_by_id.keys():
		if RETIRED_PASSIVE_IDS.has(passive_id):
			continue
		var passive: SegmentPassive = _passives_by_id[passive_id]
		if passive.is_global() or passive.character_id == character_id:
			result.append(passive)
	result.sort_custom(func(a: SegmentPassive, b: SegmentPassive) -> bool:
		var a_unlocked := is_unlocked(a.id)
		var b_unlocked := is_unlocked(b.id)
		if a_unlocked != b_unlocked:
			return a_unlocked
		return a.display_name < b.display_name
	)
	return result


## Every active passive, including character-specific ones, for collection-style browsing.
func get_all_passives() -> Array[SegmentPassive]:
	var result: Array[SegmentPassive] = []
	for passive_id: String in _passives_by_id.keys():
		if RETIRED_PASSIVE_IDS.has(passive_id):
			continue
		result.append(_passives_by_id[passive_id] as SegmentPassive)
	result.sort_custom(func(a: SegmentPassive, b: SegmentPassive) -> bool:
		var a_unlocked := is_unlocked(a.id)
		var b_unlocked := is_unlocked(b.id)
		if a_unlocked != b_unlocked:
			return a_unlocked
		return a.display_name < b.display_name
	)
	return result


func get_passive_by_id(passive_id: String) -> SegmentPassive:
	return _passives_by_id.get(passive_id) as SegmentPassive


func is_unlocked(passive_id: String) -> bool:
	if _sandbox_mode:
		return get_passive_by_id(passive_id) != null
	return _unlocked_passive_ids.has(passive_id)


## F6 debug session. All passives unlock in memory only. Copies do not write the profile.
func begin_ui_sandbox() -> void:
	ensure_loaded()
	_sandbox_mode = true
	_character_loadouts[SANDBOX_CHARACTER_ID] = _default_character_loadout()


func end_ui_sandbox() -> void:
	_sandbox_mode = false
	_character_loadouts.erase(SANDBOX_CHARACTER_ID)


func is_ui_sandbox() -> bool:
	return _sandbox_mode


func get_max_copies(passive: SegmentPassive) -> int:
	if passive == null:
		return 0
	if _sandbox_mode:
		return SANDBOX_MAX_COPIES
	return get_unlocked_copy_count(passive)


func get_unlocked_copy_count(passive: SegmentPassive) -> int:
	if passive == null:
		return 0
	if _sandbox_mode:
		return SANDBOX_MAX_COPIES
	if not is_unlocked(passive.id) and not passive.starts_unlocked:
		return 0
	var max_copies := maxi(1, passive.max_copies)
	if passive.copy_thresholds.is_empty():
		return max_copies
	var copies := 0
	for i in range(mini(max_copies, passive.copy_thresholds.size())):
		if _copy_threshold_met(passive, i):
			copies += 1
	return maxi(copies, 1 if is_unlocked(passive.id) or passive.starts_unlocked else 0)


## Unlocked copies vs max, plus progress toward the next gated copy.
func get_copy_unlock_state(passive: SegmentPassive) -> Dictionary:
	var unlocked_copies := get_unlocked_copy_count(passive)
	var max_copies := maxi(1, passive.max_copies)
	if _sandbox_mode:
		return {
			"unlocked_copies": SANDBOX_MAX_COPIES,
			"max_copies": SANDBOX_MAX_COPIES,
			"all_unlocked": true,
			"progress": 0,
			"needed": 0,
			"label": "",
		}
	if unlocked_copies >= max_copies or unlocked_copies >= passive.copy_thresholds.size():
		return {
			"unlocked_copies": unlocked_copies,
			"max_copies": max_copies,
			"all_unlocked": true,
			"progress": 0,
			"needed": 0,
			"label": "",
		}
	var needed := passive.copy_thresholds[unlocked_copies]
	var progress := _progress_value_for_copy(passive, unlocked_copies)
	return {
		"unlocked_copies": unlocked_copies,
		"max_copies": max_copies,
		"all_unlocked": false,
		"progress": progress,
		"needed": needed,
		"label": "%d / %d" % [mini(progress, needed), needed],
	}


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


func has_pending_unlock_reveals() -> bool:
	return not _pending_unlock_reveals.is_empty()


func consume_next_pending_unlock() -> SegmentPassive:
	if _pending_unlock_reveals.is_empty():
		return null
	var passive_id: String = _pending_unlock_reveals.pop_front()
	save()
	return get_passive_by_id(passive_id)


func get_selected_set_id(character_id: String) -> String:
	var char_data: Dictionary = _get_character_loadout(character_id)
	return String(char_data.get("selected_set", "A"))


func set_selected_set_id(character_id: String, set_id: String) -> void:
	if not LOADOUT_SET_IDS.has(set_id):
		return
	var char_data := _get_character_loadout(character_id)
	char_data["selected_set"] = set_id
	_character_loadouts[_resolved_character_id(character_id)] = char_data
	save()


func get_segment_placements(character_id: String, set_id: String) -> Dictionary:
	var set_data: Dictionary = _get_set_data(character_id, set_id)
	var segments: Variant = set_data.get("segments", {})
	if segments is Dictionary:
		return segments.duplicate(true)
	return {}


func get_placed_passive_ids(character_id: String, set_id: String, segment_index: int) -> Array[String]:
	var segments := get_segment_placements(character_id, set_id)
	var key := str(segment_index)
	var raw: Variant = segments.get(key, [])
	var result: Array[String] = []
	if raw is Array:
		for entry in raw:
			result.append(String(entry))
	return result


func can_place_passive(
	character_id: String,
	set_id: String,
	segment_index: int,
	passive_id: String,
	segment_tile_capacity: int
) -> bool:
	if not is_unlocked(passive_id):
		return false
	var passive := get_passive_by_id(passive_id)
	if passive == null:
		return false
	if get_remaining_copies(character_id, set_id, passive_id) <= 0:
		return false
	var used_slots := _get_used_slots(character_id, set_id, segment_index)
	return used_slots + maxi(1, passive.tile_cost) <= segment_tile_capacity


func get_remaining_copies(character_id: String, set_id: String, passive_id: String) -> int:
	var passive := get_passive_by_id(passive_id)
	if passive == null:
		return 0
	return maxi(0, get_max_copies(passive) - _count_passive_in_set(character_id, set_id, passive_id))


## Empty dest tiles append. Occupied dest tiles swap when both segments have room.
## If dest can take the dragged cost after removing the target but origin cannot
## fit the target, the target is deleted and the dragged passive moves in.
func try_relocate_passive(
	character_id: String,
	set_id: String,
	from_segment: int,
	from_list_index: int,
	to_segment: int,
	to_list_index: int,
	from_capacity: int,
	to_capacity: int
) -> Dictionary:
	var fail := {"success": false, "mode": "", "dest_list_index": -1}
	var set_data := _get_set_data(character_id, set_id)
	var segments: Dictionary = set_data.get("segments", {}).duplicate(true)
	var from_list: Array = (segments.get(str(from_segment), []) as Array).duplicate()
	if from_list_index < 0 or from_list_index >= from_list.size():
		return fail
	var dragged_id := String(from_list[from_list_index])
	var dragged_cost := _tile_cost_for_id(dragged_id)
	if dragged_cost <= 0:
		return fail

	if to_list_index < 0:
		if from_segment == to_segment:
			return fail
		var empty_dest: Array = (segments.get(str(to_segment), []) as Array).duplicate()
		if _used_from_ids(empty_dest) + dragged_cost > to_capacity:
			return fail
		from_list.remove_at(from_list_index)
		empty_dest.append(dragged_id)
		_write_segment_list(segments, from_segment, from_list)
		_write_segment_list(segments, to_segment, empty_dest)
		_commit_set_data(character_id, set_id, set_data, segments)
		return {
			"success": true,
			"mode": "move",
			"dest_list_index": empty_dest.size() - 1,
		}

	var dest_list: Array
	if from_segment == to_segment:
		dest_list = from_list
	else:
		dest_list = (segments.get(str(to_segment), []) as Array).duplicate()
	if to_list_index >= dest_list.size():
		return fail
	if from_segment == to_segment and from_list_index == to_list_index:
		return fail

	var target_id := String(dest_list[to_list_index])
	var target_cost := _tile_cost_for_id(target_id)
	if target_cost <= 0:
		return fail
	var dest_used_without_target := _used_from_ids(dest_list) - target_cost
	if dest_used_without_target + dragged_cost > to_capacity:
		return fail

	if from_segment == to_segment:
		from_list[from_list_index] = target_id
		from_list[to_list_index] = dragged_id
		_write_segment_list(segments, from_segment, from_list)
		_commit_set_data(character_id, set_id, set_data, segments)
		return {"success": true, "mode": "swap", "dest_list_index": to_list_index}

	var origin_used_without_dragged := _used_from_ids(from_list) - dragged_cost
	if origin_used_without_dragged + target_cost <= from_capacity:
		from_list[from_list_index] = target_id
		dest_list[to_list_index] = dragged_id
		_write_segment_list(segments, from_segment, from_list)
		_write_segment_list(segments, to_segment, dest_list)
		_commit_set_data(character_id, set_id, set_data, segments)
		return {"success": true, "mode": "swap", "dest_list_index": to_list_index}

	from_list.remove_at(from_list_index)
	dest_list.remove_at(to_list_index)
	dest_list.insert(to_list_index, dragged_id)
	_write_segment_list(segments, from_segment, from_list)
	_write_segment_list(segments, to_segment, dest_list)
	_commit_set_data(character_id, set_id, set_data, segments)
	return {"success": true, "mode": "replace", "dest_list_index": to_list_index}


func can_relocate_passive(
	character_id: String,
	set_id: String,
	from_segment: int,
	from_list_index: int,
	to_segment: int,
	to_list_index: int,
	to_capacity: int
) -> bool:
	var from_ids := get_placed_passive_ids(character_id, set_id, from_segment)
	if from_list_index < 0 or from_list_index >= from_ids.size():
		return false
	var dragged_cost := _tile_cost_for_id(from_ids[from_list_index])
	if dragged_cost <= 0:
		return false
	var dest_ids := get_placed_passive_ids(character_id, set_id, to_segment)
	if to_list_index < 0:
		if from_segment == to_segment:
			return false
		return _used_from_ids(dest_ids) + dragged_cost <= to_capacity
	if to_list_index >= dest_ids.size():
		return false
	if from_segment == to_segment and from_list_index == to_list_index:
		return false
	var target_cost := _tile_cost_for_id(dest_ids[to_list_index])
	if target_cost <= 0:
		return false
	return _used_from_ids(dest_ids) - target_cost + dragged_cost <= to_capacity


func _tile_cost_for_id(passive_id: String) -> int:
	var passive := get_passive_by_id(passive_id)
	if passive == null:
		return 0
	return maxi(1, passive.tile_cost)


func _used_from_ids(passive_ids: Array) -> int:
	var used := 0
	for entry in passive_ids:
		used += _tile_cost_for_id(String(entry))
	return used


func _write_segment_list(segments: Dictionary, segment_index: int, list: Array) -> void:
	var key := str(segment_index)
	if list.is_empty():
		segments.erase(key)
	else:
		segments[key] = list


func _commit_set_data(
	character_id: String,
	set_id: String,
	set_data: Dictionary,
	segments: Dictionary
) -> void:
	set_data["segments"] = segments
	_save_set_data(character_id, set_id, set_data)
	save()


func place_passive(
	character_id: String,
	set_id: String,
	segment_index: int,
	passive_id: String,
	segment_tile_capacity: int
) -> bool:
	if not can_place_passive(character_id, set_id, segment_index, passive_id, segment_tile_capacity):
		return false
	var set_data := _get_set_data(character_id, set_id)
	var segments: Dictionary = set_data.get("segments", {})
	var key := str(segment_index)
	var list: Array = segments.get(key, [])
	if list is Array:
		list = list.duplicate()
	else:
		list = []
	list.append(passive_id)
	segments[key] = list
	_commit_set_data(character_id, set_id, set_data, segments)
	return true


func remove_passive_at(
	character_id: String,
	set_id: String,
	segment_index: int,
	list_index: int
) -> void:
	var set_data := _get_set_data(character_id, set_id)
	var segments: Dictionary = set_data.get("segments", {})
	var key := str(segment_index)
	var list: Array = segments.get(key, [])
	if not list is Array or list_index < 0 or list_index >= list.size():
		return
	list = list.duplicate()
	list.remove_at(list_index)
	if list.is_empty():
		segments.erase(key)
	else:
		segments[key] = list
	_commit_set_data(character_id, set_id, set_data, segments)


func reset_segment(character_id: String, set_id: String, segment_index: int) -> void:
	var set_data := _get_set_data(character_id, set_id)
	var segments: Dictionary = set_data.get("segments", {})
	segments.erase(str(segment_index))
	_commit_set_data(character_id, set_id, set_data, segments)


func add_lifetime_triggers(amount: int) -> void:
	_add_stat("total_triggers", amount)


func add_producer_trigger() -> void:
	_add_stat("producer_triggers", 1)


func add_support_trigger() -> void:
	_add_stat("support_triggers", 1)


func add_producer_retrigger() -> void:
	_add_stat("producer_retriggers", 1)


func add_support_retrigger() -> void:
	_add_stat("support_retriggers", 1)
	_run_peaks["support_retriggers"] = int(_run_peaks.get("support_retriggers", 0)) + 1
	_lifetime_stats["peak_support_retriggers_in_run"] = maxi(
		int(_lifetime_stats.get("peak_support_retriggers_in_run", 0)),
		int(_run_peaks.get("support_retriggers", 0))
	)


func add_last_producer_trigger() -> void:
	_add_stat("last_producer_triggers", 1)


func add_alternating_activation() -> void:
	_add_stat("alternating_activations", 1)


func add_spectrum_turn() -> void:
	_add_stat("spectrum_turns", 1)


func add_support_then_producer() -> void:
	_add_stat("support_then_producer", 1)


func add_support_affected_producer() -> void:
	_add_stat("support_affected_producers", 1)


func add_adjacent_same_product_trigger() -> void:
	_add_stat("adjacent_same_product_triggers", 1)


func add_full_segment_turn() -> void:
	_add_stat("full_segment_turns", 1)


func note_resonant_array_fill() -> void:
	_lifetime_stats["resonant_array_fill"] = true


func record_card_broken(on_one_tile: bool) -> void:
	_add_stat("cards_broken", 1)
	if on_one_tile:
		_add_stat("one_tile_breaks", 1)


func add_break_prevented_by_fuse() -> void:
	_add_stat("breaks_prevented_by_fuse", 1)


func add_one_tile_activation() -> void:
	_add_stat("one_tile_activations", 1)


func note_energy_card_triggers(count_on_card: int) -> void:
	_lifetime_stats["peak_energy_card_triggers_in_run"] = maxi(
		int(_lifetime_stats.get("peak_energy_card_triggers_in_run", 0)),
		count_on_card
	)


func note_mult_card_triggers(count_on_card: int) -> void:
	_lifetime_stats["peak_mult_card_triggers_in_run"] = maxi(
		int(_lifetime_stats.get("peak_mult_card_triggers_in_run", 0)),
		count_on_card
	)


func note_energy_bonus(bonus: float) -> void:
	_lifetime_stats["peak_energy_bonus_in_run"] = maxi(
		int(_lifetime_stats.get("peak_energy_bonus_in_run", 0)),
		int(round(bonus))
	)


func note_mult_bonus(bonus: float) -> void:
	var tenths := int(round(bonus * 10.0))
	_lifetime_stats["peak_mult_bonus_tenths_in_run"] = maxi(
		int(_lifetime_stats.get("peak_mult_bonus_tenths_in_run", 0)),
		tenths
	)


func note_one_tile_same_card_triggers(count_on_card: int) -> void:
	_lifetime_stats["peak_one_tile_same_card_triggers"] = maxi(
		int(_lifetime_stats.get("peak_one_tile_same_card_triggers", 0)),
		count_on_card
	)


func begin_run_tracking() -> void:
	_run_peaks = {"support_retriggers": 0}


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


func _copy_threshold_met(passive: SegmentPassive, copy_index: int) -> bool:
	if copy_index < 0 or copy_index >= passive.copy_thresholds.size():
		return false
	var needed := passive.copy_thresholds[copy_index]
	if needed <= 0:
		return true
	return _progress_value_for_copy(passive, copy_index) >= needed


## Gilded Contact copy 2 gates on peak gold held. Other copies use the unlock stat.
func _progress_value_for_copy(passive: SegmentPassive, copy_index: int) -> int:
	if passive.unlock_condition == null:
		return 0
	if (
		copy_index > 0
		and passive.unlock_condition.extra_threshold > 0
		and passive.unlock_condition.condition_type == UnlockCondition.Type.GOLD_EARNED_IN_RUN
	):
		return int(_lifetime_stats.get("peak_gold_held", 0))
	return _progress_for_condition(passive.unlock_condition, {})


func record_run_snapshot(snapshot: Dictionary, finalize_unlocks: bool) -> void:
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
		if int(snapshot.get("peak_gold_held", 0)) >= 40:
			_lifetime_stats["win_difficulty_with_40_gold"] = maxi(
				int(_lifetime_stats.get("win_difficulty_with_40_gold", 0)),
				win_difficulty
			)
	if bool(snapshot.get("full_map_cards", false)):
		_lifetime_stats["full_map_cards_achieved"] = true

	if finalize_unlocks:
		_evaluate_all_unlocks(snapshot)
	save()


func get_unlock_progress_value(passive: SegmentPassive) -> int:
	if passive == null or passive.unlock_condition == null:
		return 0
	return _progress_for_condition(passive.unlock_condition, {})


## Ratio and caption for locked rows, including OR unlocks with two gates.
func get_unlock_progress_display(passive: SegmentPassive) -> Dictionary:
	if passive == null or passive.unlock_condition == null:
		return {"ratio": 0.0, "label": ""}
	var condition := passive.unlock_condition
	if condition.condition_type == UnlockCondition.Type.PRODUCER_RETRIGGERS_OR_TURN_TRIGGERS:
		var retriggers := int(_lifetime_stats.get("producer_retriggers", 0))
		var turn_peak := int(_lifetime_stats.get("peak_triggers_single_turn", 0))
		var retrigger_gate := maxi(condition.threshold, 1)
		var turn_gate := maxi(condition.extra_threshold, 1)
		var ratio := maxf(
			clampf(float(retriggers) / float(retrigger_gate), 0.0, 1.0),
			clampf(float(turn_peak) / float(turn_gate), 0.0, 1.0)
		)
		return {
			"ratio": ratio,
			"label": "%d / %d retriggers, or %d / %d in one turn" % [
				mini(retriggers, retrigger_gate),
				retrigger_gate,
				mini(turn_peak, turn_gate),
				turn_gate,
			],
		}
	var current := _progress_for_condition(condition, {})
	return {
		"ratio": condition.get_progress_ratio(current),
		"label": condition.get_progress_label(current),
	}


func _progress_for_condition(condition: UnlockCondition, snapshot: Dictionary) -> int:
	match condition.condition_type:
		UnlockCondition.Type.LIFETIME_TRIGGERS:
			return int(_lifetime_stats.get("total_triggers", 0))
		UnlockCondition.Type.WIN_RUN:
			return int(_lifetime_stats.get("wins", 0))
		UnlockCondition.Type.GOLD_HELD:
			return int(_lifetime_stats.get("peak_gold_held", 0))
		UnlockCondition.Type.SEGMENT_SCORE_SINGLE_TURN:
			return int(_lifetime_stats.get("peak_segment_score_single_turn", 0))
		UnlockCondition.Type.TRIGGERS_SINGLE_TURN:
			return int(_lifetime_stats.get("peak_triggers_single_turn", 0))
		UnlockCondition.Type.FULL_MAP_CARDS:
			return 1 if bool(_lifetime_stats.get("full_map_cards_achieved", false)) else 0
		UnlockCondition.Type.PRODUCER_TRIGGERS:
			return int(_lifetime_stats.get("producer_triggers", 0))
		UnlockCondition.Type.SUPPORT_TRIGGERS:
			return int(_lifetime_stats.get("support_triggers", 0))
		UnlockCondition.Type.PRODUCER_RETRIGGERS:
			return int(_lifetime_stats.get("producer_retriggers", 0))
		UnlockCondition.Type.SUPPORT_RETRIGGERS_IN_RUN:
			return int(_lifetime_stats.get("peak_support_retriggers_in_run", 0))
		UnlockCondition.Type.RUNS_COMPLETED:
			return int(_lifetime_stats.get("runs_completed", 0))
		UnlockCondition.Type.WIN_DIFFICULTY:
			return int(_lifetime_stats.get("highest_win_difficulty", 0))
		UnlockCondition.Type.GOLD_EARNED_IN_RUN:
			return int(_lifetime_stats.get("peak_gold_earned_in_run", 0))
		UnlockCondition.Type.ENERGY_CARD_TRIGGERS_IN_RUN:
			return int(_lifetime_stats.get("peak_energy_card_triggers_in_run", 0))
		UnlockCondition.Type.MULT_CARD_TRIGGERS_IN_RUN:
			return int(_lifetime_stats.get("peak_mult_card_triggers_in_run", 0))
		UnlockCondition.Type.ENERGY_BONUS_IN_RUN:
			return int(_lifetime_stats.get("peak_energy_bonus_in_run", 0))
		UnlockCondition.Type.MULT_BONUS_IN_RUN:
			return int(_lifetime_stats.get("peak_mult_bonus_tenths_in_run", 0))
		UnlockCondition.Type.CARDS_BROKEN:
			return int(_lifetime_stats.get("cards_broken", 0))
		UnlockCondition.Type.BREAKS_PREVENTED_BY_FUSE:
			return int(_lifetime_stats.get("breaks_prevented_by_fuse", 0))
		UnlockCondition.Type.ALTERNATING_ACTIVATIONS:
			return int(_lifetime_stats.get("alternating_activations", 0))
		UnlockCondition.Type.SPECTRUM_TURNS:
			return int(_lifetime_stats.get("spectrum_turns", 0))
		UnlockCondition.Type.SUPPORT_THEN_PRODUCER:
			return int(_lifetime_stats.get("support_then_producer", 0))
		UnlockCondition.Type.SUPPORT_AFFECTED_PRODUCERS:
			return int(_lifetime_stats.get("support_affected_producers", 0))
		UnlockCondition.Type.ADJACENT_SAME_PRODUCT_TRIGGERS:
			return int(_lifetime_stats.get("adjacent_same_product_triggers", 0))
		UnlockCondition.Type.ONE_TILE_ACTIVATIONS:
			return int(_lifetime_stats.get("one_tile_activations", 0))
		UnlockCondition.Type.ONE_TILE_BREAKS:
			return int(_lifetime_stats.get("one_tile_breaks", 0))
		UnlockCondition.Type.ONE_TILE_SAME_CARD_TRIGGERS_IN_RUN:
			return int(_lifetime_stats.get("peak_one_tile_same_card_triggers", 0))
		UnlockCondition.Type.LAST_PRODUCER_TRIGGERS:
			return int(_lifetime_stats.get("last_producer_triggers", 0))
		UnlockCondition.Type.FULL_SEGMENT_TURNS:
			return int(_lifetime_stats.get("full_segment_turns", 0))
		UnlockCondition.Type.RESONANT_ARRAY_FILL:
			return 1 if bool(_lifetime_stats.get("resonant_array_fill", false)) else 0
		UnlockCondition.Type.LAYOUT_LEVEL:
			var layout_id := condition.character_id
			if layout_id.is_empty():
				layout_id = String(snapshot.get("character_id", ""))
			return get_layout_level(layout_id)
		UnlockCondition.Type.PRODUCER_RETRIGGERS_OR_TURN_TRIGGERS:
			return maxi(
				int(_lifetime_stats.get("producer_retriggers", 0)),
				int(_lifetime_stats.get("peak_triggers_single_turn", 0))
			)
		UnlockCondition.Type.WIN_DIFFICULTY_AND_GOLD:
			return int(_lifetime_stats.get("win_difficulty_with_40_gold", 0))
		_:
			return 0


func _init_defaults() -> void:
	_unlocked_passive_ids.clear()
	_lifetime_stats = {
		"total_triggers": 0,
		"wins": 0,
		"losses": 0,
		"runs_completed": 0,
		"peak_gold_held": 0,
		"peak_gold_earned_in_run": 0,
		"peak_segment_score_single_turn": 0,
		"peak_triggers_single_turn": 0,
		"full_map_cards_achieved": false,
	}
	_layout_xp.clear()
	_character_loadouts.clear()
	_pending_unlock_reveals.clear()
	begin_run_tracking()


func _apply_save_data(data: Dictionary) -> void:
	_unlocked_passive_ids.clear()
	for entry in data.get("unlocked_passive_ids", []):
		_unlocked_passive_ids.append(String(entry))
	_lifetime_stats = data.get("lifetime_stats", {}).duplicate(true)
	_layout_xp = data.get("layout_xp", {}).duplicate(true)
	_character_loadouts = data.get("character_loadouts", {}).duplicate(true)
	_pending_unlock_reveals.clear()
	for entry in data.get("pending_unlock_reveals", []):
		_pending_unlock_reveals.append(String(entry))
	if _strip_retired_passives():
		save()


func _load_passive_resources() -> void:
	_passives_by_id.clear()
	_load_passives_from_directory(PASSIVES_DIR)
	_grant_starting_unlocks()
	if _strip_retired_passives():
		save()


func _load_passives_from_directory(dir_path: String) -> void:
	var normalized_path := dir_path
	if not normalized_path.ends_with("/"):
		normalized_path += "/"
	for entry in ResourceLoader.list_directory(normalized_path):
		if entry == "./" or entry == "../":
			continue
		var full_path := normalized_path + entry
		if entry.ends_with("/"):
			_load_passives_from_directory(full_path)
			continue
		if not entry.ends_with(".tres"):
			continue
		var resource := load(full_path)
		if resource is SegmentPassive:
			var passive := resource as SegmentPassive
			if passive.id.is_empty():
				continue
			_passives_by_id[passive.id] = passive


func _resolved_character_id(character_id: String) -> String:
	if _sandbox_mode:
		return SANDBOX_CHARACTER_ID
	return character_id


func _get_character_loadout(character_id: String) -> Dictionary:
	character_id = _resolved_character_id(character_id)
	if not _character_loadouts.has(character_id):
		_character_loadouts[character_id] = _default_character_loadout()
	return _character_loadouts[character_id]


func _default_character_loadout() -> Dictionary:
	return {
		"selected_set": "A",
		"sets": {
			"A": {"segments": {}},
			"B": {"segments": {}},
			"C": {"segments": {}},
		},
	}


func _get_set_data(character_id: String, set_id: String) -> Dictionary:
	var char_data := _get_character_loadout(character_id)
	var sets: Dictionary = char_data.get("sets", {})
	var set_data: Variant = sets.get(set_id, {"segments": {}})
	if set_data is Dictionary:
		return set_data.duplicate(true)
	return {"segments": {}}


func _save_set_data(character_id: String, set_id: String, set_data: Dictionary) -> void:
	var char_data := _get_character_loadout(character_id)
	var sets: Dictionary = char_data.get("sets", {})
	sets[set_id] = set_data
	char_data["sets"] = sets
	_character_loadouts[_resolved_character_id(character_id)] = char_data


func _get_used_slots(character_id: String, set_id: String, segment_index: int) -> int:
	return _used_from_ids(get_placed_passive_ids(character_id, set_id, segment_index))


func _count_passive_in_set(character_id: String, set_id: String, passive_id: String) -> int:
	var count := 0
	var segments := get_segment_placements(character_id, set_id)
	for segment_key: String in segments.keys():
		var list: Variant = segments[segment_key]
		if list is Array:
			for entry in list:
				if String(entry) == passive_id:
					count += 1
	return count


func _evaluate_all_unlocks(run_snapshot: Dictionary) -> void:
	for passive_id: String in _passives_by_id.keys():
		if is_unlocked(passive_id):
			continue
		var passive: SegmentPassive = _passives_by_id[passive_id]
		if passive.starts_unlocked:
			continue
		if _passive_meets_unlock(passive, run_snapshot):
			_unlock_passive(passive_id)


func _passive_meets_unlock(passive: SegmentPassive, run_snapshot: Dictionary) -> bool:
	if passive.unlock_condition == null:
		return false
	var condition := passive.unlock_condition
	if condition.condition_type == UnlockCondition.Type.MANUAL_LOCK:
		return false
	if condition.condition_type == UnlockCondition.Type.PRODUCER_RETRIGGERS_OR_TURN_TRIGGERS:
		var retriggers := int(_lifetime_stats.get("producer_retriggers", 0))
		var turn_peak := int(_lifetime_stats.get("peak_triggers_single_turn", 0))
		return retriggers >= condition.threshold or turn_peak >= maxi(condition.extra_threshold, 1)
	return _progress_for_condition(condition, run_snapshot) >= condition.threshold


## Starter passives skip the deferred reveal queue. Existing saves pick them up on load.
func _grant_starting_unlocks() -> void:
	var granted := false
	for passive_id: String in _passives_by_id.keys():
		var passive: SegmentPassive = _passives_by_id[passive_id]
		if not passive.starts_unlocked:
			continue
		if _unlocked_passive_ids.has(passive_id):
			continue
		_unlocked_passive_ids.append(passive_id)
		granted = true
	if granted:
		save()


## Drops retired passive ids from unlocks and placed loadouts so old saves stay valid.
func _strip_retired_passives() -> bool:
	var changed := false
	for retired_id: String in RETIRED_PASSIVE_IDS:
		var replacement_id := String(PASSIVE_ID_MIGRATIONS.get(retired_id, ""))
		if _unlocked_passive_ids.has(retired_id):
			_unlocked_passive_ids.erase(retired_id)
			if not replacement_id.is_empty() and not _unlocked_passive_ids.has(replacement_id):
				_unlocked_passive_ids.append(replacement_id)
			changed = true
		if _pending_unlock_reveals.has(retired_id):
			_pending_unlock_reveals.erase(retired_id)
			if not replacement_id.is_empty() and not _pending_unlock_reveals.has(replacement_id):
				_pending_unlock_reveals.append(replacement_id)
			changed = true
		for character_id: String in _character_loadouts.keys():
			var char_data: Dictionary = _character_loadouts[character_id]
			var sets: Dictionary = char_data.get("sets", {})
			for set_id: String in sets.keys():
				var set_data: Variant = sets[set_id]
				if not set_data is Dictionary:
					continue
				var segments: Dictionary = set_data.get("segments", {})
				for segment_key: String in segments.keys():
					var list: Variant = segments[segment_key]
					if not list is Array:
						continue
					var filtered: Array = []
					for entry in list:
						var passive_id := String(entry)
						if RETIRED_PASSIVE_IDS.has(passive_id):
							changed = true
							if not replacement_id.is_empty():
								filtered.append(replacement_id)
							continue
						filtered.append(passive_id)
					if filtered.is_empty():
						segments.erase(segment_key)
					else:
						segments[segment_key] = filtered
	return changed


func _unlock_passive(passive_id: String) -> void:
	if is_unlocked(passive_id):
		return
	_unlocked_passive_ids.append(passive_id)
	if not _pending_unlock_reveals.has(passive_id):
		_pending_unlock_reveals.append(passive_id)
