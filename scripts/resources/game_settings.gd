class_name GameSettings
extends RefCounted

## Persistent player options stored in user://, independent of the current run save.

const SAVE_PATH := "user://game_settings.save"

## When true, the in-run tutorial banner appears the next time a run starts.
static var tutorial_enabled: bool = true
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return
	var settings = save_file.get_var()
	if settings is Dictionary:
		tutorial_enabled = bool(settings.get("tutorial_enabled", true))


static func set_tutorial_enabled(value: bool) -> void:
	ensure_loaded()
	if tutorial_enabled == value:
		return
	tutorial_enabled = value
	_save()


## Consumes the one-shot so the tutorial does not appear on later runs.
static func consume_tutorial_on_run_start() -> bool:
	ensure_loaded()
	if not tutorial_enabled:
		return false
	tutorial_enabled = false
	_save()
	return true


static func _save() -> void:
	var settings := {
		"tutorial_enabled": tutorial_enabled,
	}
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("GameSettings: failed to write %s" % SAVE_PATH)
		return
	save_file.store_var(settings)
