extends RefCounted

## Captures Godot script errors during headless playtests via OS.add_logger.
## PlaytestRunner drains new errors after each turn and fails the case on any hit.

static var _mutex := Mutex.new()
static var _errors: Array[String] = []
static var _watermark: int = 0
static var _logger_registered := false


static func ensure_logger() -> void:
	if _logger_registered:
		return
	OS.add_logger(load("res://scripts/debug/playtest_script_error_logger.gd").new())
	_logger_registered = true


## Ignore errors that occurred before the current playtest case started.
static func mark() -> void:
	_mutex.lock()
	_watermark = _errors.size()
	_mutex.unlock()


## Return script errors logged since the last mark() or collect_new() call.
static func collect_new() -> Array[String]:
	_mutex.lock()
	var result: Array[String] = []
	for index in range(_watermark, _errors.size()):
		result.append(_errors[index])
	_watermark = _errors.size()
	_mutex.unlock()
	return result


static func record_error(summary: String) -> void:
	if summary.strip_edges().is_empty():
		return
	_mutex.lock()
	_errors.append(summary)
	_mutex.unlock()
