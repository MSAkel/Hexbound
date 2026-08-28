extends Node

## Persistent meta progression: global passive unlocks and per-character passive sets (A/B/C).

const SAVE_PATH := "user://player_profile.save"
const PASSIVES_DIR := "res://resources/segment_passives/"
const LOADOUT_SET_IDS: Array[String] = ["A", "B", "C"]
const RETIRED_PASSIVE_IDS: Array[String] = ["spark", "spark_surge", "steady_growth"]
const PASSIVE_ID_MIGRATIONS: Dictionary = {
	"steady_growth": "power_boost",
}
const SANDBOX_CHARACTER_ID := "_ui_sandbox"
const SANDBOX_MAX_COPIES := 8

var _loaded: bool = false
var _sandbox_mode: bool = false
var _passives_by_id: Dictionary = {}
var _unlocked_passive_ids: Array[String] = []
var _lifetime_stats: Dictionary = {}
var _character_loadouts: Dictionary = {}
var _pending_unlock_reveals: Array[String] = []


func _ready() -> void:
	ensure_loaded()
	_load_passive_resources()


func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		_init_defaults()
		return
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		_init_defaults()
		return
	var data: Variant = save_file.get_var()
	if data is Dictionary:
		_apply_save_data(data)
	else:
		_init_defaults()


func save() -> void:
	if _sandbox_mode:
		return
	var data := {
		"version": 1,
		"unlocked_passive_ids": _unlocked_passive_ids.duplicate(),
		"lifetime_stats": _lifetime_stats.duplicate(),
		"character_loadouts": _character_loadouts.duplicate(true),
		"pending_unlock_reveals": _pending_unlock_reveals.duplicate(),
	}
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("MetaProgressionManager: failed to write profile save")
		return
	save_file.store_var(data)


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
	return maxi(1, passive.max_copies)


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
	if amount <= 0 or RunRng.is_unlock_progress_disabled():
		return
	_lifetime_stats["total_triggers"] = int(_lifetime_stats.get("total_triggers", 0)) + amount


func record_run_snapshot(snapshot: Dictionary, finalize_unlocks: bool) -> void:
	if RunRng.is_unlock_progress_disabled():
		return

	var is_win := bool(snapshot.get("is_win", false))
	if is_win:
		_lifetime_stats["wins"] = int(_lifetime_stats.get("wins", 0)) + 1
	else:
		_lifetime_stats["losses"] = int(_lifetime_stats.get("losses", 0)) + 1

	var peak_gold := int(snapshot.get("peak_gold_held", 0))
	_lifetime_stats["peak_gold_held"] = maxi(
		int(_lifetime_stats.get("peak_gold_held", 0)),
		peak_gold
	)
	var peak_segment_score := int(snapshot.get("peak_segment_score_single_turn", 0))
	_lifetime_stats["peak_segment_score_single_turn"] = maxi(
		int(_lifetime_stats.get("peak_segment_score_single_turn", 0)),
		peak_segment_score
	)
	var peak_turn_triggers := int(snapshot.get("peak_triggers_single_turn", 0))
	_lifetime_stats["peak_triggers_single_turn"] = maxi(
		int(_lifetime_stats.get("peak_triggers_single_turn", 0)),
		peak_turn_triggers
	)
	if bool(snapshot.get("full_map_cards", false)):
		_lifetime_stats["full_map_cards_achieved"] = true

	if finalize_unlocks:
		_evaluate_all_unlocks(snapshot)
	save()


func get_unlock_progress_value(passive: SegmentPassive) -> int:
	if passive.unlock_condition == null:
		return 0
	match passive.unlock_condition.condition_type:
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
		_:
			return 0


func _init_defaults() -> void:
	_unlocked_passive_ids.clear()
	_lifetime_stats = {
		"total_triggers": 0,
		"wins": 0,
		"losses": 0,
		"peak_gold_held": 0,
		"peak_segment_score_single_turn": 0,
		"peak_triggers_single_turn": 0,
		"full_map_cards_achieved": false,
	}
	_character_loadouts.clear()
	_pending_unlock_reveals.clear()


func _apply_save_data(data: Dictionary) -> void:
	_unlocked_passive_ids.clear()
	for entry in data.get("unlocked_passive_ids", []):
		_unlocked_passive_ids.append(String(entry))
	_lifetime_stats = data.get("lifetime_stats", {}).duplicate(true)
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
	match condition.condition_type:
		UnlockCondition.Type.MANUAL_LOCK:
			return false
		UnlockCondition.Type.LIFETIME_TRIGGERS:
			return int(_lifetime_stats.get("total_triggers", 0)) >= condition.threshold
		UnlockCondition.Type.WIN_RUN:
			if not bool(run_snapshot.get("is_win", false)):
				return false
			if condition.character_id.is_empty():
				return true
			return String(run_snapshot.get("character_id", "")) == condition.character_id
		UnlockCondition.Type.GOLD_HELD:
			return int(_lifetime_stats.get("peak_gold_held", 0)) >= condition.threshold
		UnlockCondition.Type.SEGMENT_SCORE_SINGLE_TURN:
			return int(_lifetime_stats.get("peak_segment_score_single_turn", 0)) >= condition.threshold
		UnlockCondition.Type.TRIGGERS_SINGLE_TURN:
			return int(_lifetime_stats.get("peak_triggers_single_turn", 0)) >= condition.threshold
		UnlockCondition.Type.FULL_MAP_CARDS:
			return bool(_lifetime_stats.get("full_map_cards_achieved", false))
	return false


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
