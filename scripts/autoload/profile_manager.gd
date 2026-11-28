extends Node

## Player profiles: three numbered slots, each a folder holding everything that is progress (run in
## progress, chef XP and Collection stats, lifetime stats, run history, tutorial progress). Settings
## stay shared in user://game_settings.save. Design: the project doc "Flavour Pass: Player Profiles
## Design". Listed first in [autoload] so every save owner can ask for its path in _ready().
##
## Layout under root_dir():
##   profiles.cfg            active slot (shared)
##   profiles/<slot>/        one folder per slot, created on its first write
##     profile.cfg           summary for the profile screen, last chef shown, unlock_all
##
## An empty slot has no folder and is a valid profile: every owner falls back to defaults.
## Saves from before profiles are not migrated (user, Nov 28).

signal profile_changed(slot: int)
signal summary_changed(slot: int)

const SLOT_COUNT := 3
const FORMAT_VERSION := 1
const SLOTS_FILE := "profiles.cfg"
const PROFILE_FILE := "profile.cfg"
const RUN_SAVE_FILE := "run_save.json"
const SECTION := "profile"
## Editor runs (Play in the editor, CI, the bot) keep their saves apart, so an exported build on the
## same PC opens on fresh profiles, as a new player's would.
const DEV_ROOT := "user://dev/"
const RELEASE_ROOT := "user://"

var active_slot := 1
## Tests and checks force Unlock all on (1) or off (0) without touching a profile; -1 reads the flag.
var unlock_all_override := -1

## The active profile's profile.cfg, cached.
var _profile: Dictionary = {}
var _unsaved_play_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var slots := ConfigFile.new()
	if slots.load(root_dir() + SLOTS_FILE) == OK:
		active_slot = clampi(int(slots.get_value(SECTION, "active_slot", 1)), 1, SLOT_COUNT)
	_profile = _read_profile(active_slot)


func _process(delta: float) -> void:
	_unsaved_play_time += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_play_time()


#region Paths

func root_dir() -> String:
	return DEV_ROOT if OS.has_feature("editor") else RELEASE_ROOT


func profile_dir(slot: int = -1) -> String:
	return root_dir() + "profiles/%d/" % (active_slot if slot < 1 else slot)


## Path of a file in the active profile. Nothing is created here: AtomicSaveFile makes the folder
## on the first write, so reading an empty slot leaves it empty.
func path(file_name: String) -> String:
	return profile_dir() + file_name


func is_slot_used(slot: int) -> bool:
	return DirAccess.dir_exists_absolute(profile_dir(slot))

#endregion


#region Slots

## What the profile screen shows for a slot. {} = empty slot. Keys: last_played (unix seconds),
## play_time (seconds), wins, highest_win_difficulty (1-8, 0 = none), top_chef_level,
## has_run, unlock_all.
func slot_summary(slot: int) -> Dictionary:
	if not is_slot_used(slot):
		return {}
	var profile := _profile if slot == active_slot else _read_profile(slot)
	var play_time := float(profile.get("play_time", 0.0))
	if slot == active_slot:
		play_time += _unsaved_play_time
	return {
		"last_played": int(profile.get("last_played", 0)),
		"play_time": play_time,
		"wins": int(profile.get("wins", 0)),
		"highest_win_difficulty": int(profile.get("highest_win_difficulty", 0)),
		"top_chef_level": int(profile.get("top_chef_level", 1)),
		"has_run": AtomicSaveFile.has_readable(profile_dir(slot) + RUN_SAVE_FILE),
		"unlock_all": bool(profile.get("unlock_all", false)),
	}


## Main menu only: no run scene may be loaded.
func switch_to(slot: int) -> void:
	slot = clampi(slot, 1, SLOT_COUNT)
	if slot == active_slot:
		return
	flush_play_time()
	active_slot = slot
	_unsaved_play_time = 0.0
	_write_slots_file()
	_reload_all()


## Removes the slot's folder. Deleting the active slot reloads it as an empty profile.
func delete_slot(slot: int) -> void:
	_remove_dir(profile_dir(slot))
	if slot == active_slot:
		_unsaved_play_time = 0.0
		_reload_all()
	else:
		summary_changed.emit(slot)


func _reload_all() -> void:
	_profile = _read_profile(active_slot)
	RunSaveManager.reload()
	CollectionStats.reload()
	MetaProgressionManager.reload()
	RunHistoryManager.reload()
	TutorialManager.reload()
	profile_changed.emit(active_slot)

#endregion


#region Active profile

func is_unlock_all() -> bool:
	if unlock_all_override >= 0:
		return unlock_all_override == 1
	return bool(_profile.get("unlock_all", false))


## Unlock all (Balatro-style): one flag, no faked stats or XP. Every lock asks is_unlock_all().
## It can't be undone; only deleting the profile clears it. Also turns off Steam achievements for
## the profile once they exist.
func set_unlock_all() -> void:
	_profile["unlock_all"] = true
	_write_profile()


func get_last_chef_selection_id() -> String:
	return String(_profile.get("last_chef_selection_id", ""))


func set_last_chef_selection_id(chef_id: String) -> void:
	if get_last_chef_selection_id() == chef_id:
		return
	_profile["last_chef_selection_id"] = chef_id
	_write_profile()


## Re-caches the summary line (wins, highest difficulty won, top chef level). Called when a run's
## stats are merged.
func refresh_summary() -> void:
	var lifetime := MetaProgressionManager.get_lifetime_stats_snapshot()
	_profile["wins"] = int(lifetime.get("wins", 0))
	_profile["highest_win_difficulty"] = int(lifetime.get("highest_win_difficulty", 0))
	var top_level := 1
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		top_level = maxi(top_level, int(CollectionStats.get_chef_stats(chef.id)["level"]))
	_profile["top_chef_level"] = top_level
	_write_profile()


## Adds the time played since the last flush. Only for a profile that already has a folder, so
## looking at an empty slot and quitting leaves it empty.
func flush_play_time() -> void:
	if _unsaved_play_time <= 0.0 or not is_slot_used(active_slot):
		return
	_write_profile()

#endregion


func _is_writable() -> bool:
	return DisplayServer.get_name() != "headless"


func _write_profile() -> void:
	if not _is_writable():
		return
	_profile["play_time"] = float(_profile.get("play_time", 0.0)) + _unsaved_play_time
	_unsaved_play_time = 0.0
	var now := int(Time.get_unix_time_from_system())
	if not _profile.has("created"):
		_profile["created"] = now
	_profile["last_played"] = now
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", FORMAT_VERSION)
	for key: String in _profile:
		config.set_value(SECTION, key, _profile[key])
	if not AtomicSaveFile.write_text(path(PROFILE_FILE), config.encode_to_text()):
		push_error("ProfileManager: failed to write %s." % path(PROFILE_FILE))
	summary_changed.emit(active_slot)


func _read_profile(slot: int) -> Dictionary:
	var file_path := profile_dir(slot) + PROFILE_FILE
	var profile: Dictionary = {}
	for candidate: String in [file_path, AtomicSaveFile.bak_path(file_path)]:
		var config := ConfigFile.new()
		if FileAccess.file_exists(candidate) and config.load(candidate) == OK:
			for key: String in config.get_section_keys(SECTION):
				if key != "version":
					profile[key] = config.get_value(SECTION, key)
			break
	return profile


func _write_slots_file() -> void:
	if not _is_writable():
		return
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", FORMAT_VERSION)
	config.set_value(SECTION, "active_slot", active_slot)
	if not AtomicSaveFile.write_text(root_dir() + SLOTS_FILE, config.encode_to_text()):
		push_error("ProfileManager: failed to write %s." % SLOTS_FILE)


## A profile folder is flat (save files and their .tmp / .bak).
func _remove_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path + file_name)
	DirAccess.remove_absolute(dir_path)
