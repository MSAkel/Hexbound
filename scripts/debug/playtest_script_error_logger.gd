extends Logger

const TRACKER := preload("res://scripts/debug/playtest_script_error_tracker.gd")


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	var detail := rationale if not rationale.is_empty() else code
	TRACKER.record_error("%s:%d %s" % [file.get_file(), line, detail])


func _log_message(message: String, error: bool) -> void:
	# Script errors also print a SCRIPT ERROR line to stderr in some builds.
	if error and message.contains("SCRIPT ERROR"):
		TRACKER.record_error(message.strip_edges())
