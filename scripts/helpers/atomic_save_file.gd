class_name AtomicSaveFile
extends RefCounted

## Crash-safe replace for user:// files. A half-written save cannot wipe the last good one.


static func tmp_path(path: String) -> String:
	return path + ".tmp"


static func bak_path(path: String) -> String:
	return path + ".bak"


## True when the main file or a readable backup exists. Tmp is never treated as a save.
static func has_readable(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(bak_path(path))


static func delete_all(path: String) -> void:
	_remove_if_exists(path)
	_remove_if_exists(tmp_path(path))
	_remove_if_exists(bak_path(path))


static func write_text(path: String, text: String) -> bool:
	if not _write_tmp_text(path, text):
		return false
	return _commit_tmp(path)


static func write_var(path: String, value: Variant) -> bool:
	if not _write_tmp_var(path, value):
		return false
	return _commit_tmp(path)


## First readable JSON object from the main file, then the bak. Corrupt main does not hide a good bak.
static func read_json_dictionary(path: String) -> Dictionary:
	for candidate in [path, bak_path(path)]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			return parsed
	return {}


## First readable Dictionary from store_var, main then bak.
static func read_var_dictionary(path: String) -> Dictionary:
	for candidate in [path, bak_path(path)]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = file.get_var()
		if parsed is Dictionary:
			return parsed
	return {}


static func _write_tmp_text(path: String, text: String) -> bool:
	var tmp := tmp_path(path)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("AtomicSaveFile: cannot open tmp for writing (%s)." % tmp)
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


static func _write_tmp_var(path: String, value: Variant) -> bool:
	var tmp := tmp_path(path)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("AtomicSaveFile: cannot open tmp for writing (%s)." % tmp)
		return false
	file.store_var(value)
	file.flush()
	file.close()
	return true


## Write tmp, park the current file as bak, then rename tmp into place.
static func _commit_tmp(path: String) -> bool:
	var tmp := tmp_path(path)
	var bak := bak_path(path)
	var path_abs := ProjectSettings.globalize_path(path)
	var tmp_abs := ProjectSettings.globalize_path(tmp)
	var bak_abs := ProjectSettings.globalize_path(bak)

	_remove_if_exists(bak)

	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(path_abs, bak_abs) != OK:
			push_error("AtomicSaveFile: failed to move current file to bak (%s)." % path)
			return false

	if DirAccess.rename_absolute(tmp_abs, path_abs) != OK:
		push_error("AtomicSaveFile: failed to install tmp as save file (%s)." % path)
		# Put the last good file back if the main path is missing.
		if FileAccess.file_exists(bak) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(bak_abs, path_abs)
		return false

	_remove_if_exists(bak)
	return true


static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
