class_name GameSettings
extends RefCounted

## Persistent player options stored in user://, independent of the current run save.

const SAVE_PATH := "user://game_settings.save"

const DISPLAY_MODE_FULLSCREEN := 0
const DISPLAY_MODE_WINDOWED := 1
const DISPLAY_MODE_BORDERLESS := 2

const RESOLUTIONS := [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

## When true, the in-run tutorial banner appears the next time a run starts.
static var tutorial_enabled: bool = true
static var screen_shake_enabled: bool = true
static var game_speed: float = 1.0
static var vsync_enabled: bool = false
static var music_volume: float = 0.20
static var sfx_volume: float = 0.35
static var display_mode: int = DISPLAY_MODE_WINDOWED
static var resolution: Vector2i = Vector2i(1920, 1080)
## Last character shown on the character selection screen, even if no run was started.
static var last_character_selection_id: String = ""
static var _loaded: bool = false


static func detect_device_resolution() -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	return snap_resolution_to_preset(DisplayServer.screen_get_size(screen))


## Maps saved or detected sizes onto the nearest supported preset.
static func snap_resolution_to_preset(value: Vector2i) -> Vector2i:
	for preset in RESOLUTIONS:
		if preset == value:
			return preset
	var best := RESOLUTIONS[0]
	var best_distance := _resolution_distance(value, best)
	for preset in RESOLUTIONS:
		var distance := _resolution_distance(value, preset)
		if distance < best_distance:
			best_distance = distance
			best = preset
	return best


static func _resolution_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		# First launch. Match the monitor and start windowed.
		resolution = detect_device_resolution()
		display_mode = DISPLAY_MODE_WINDOWED
		_apply_display_settings()
		_apply_vsync()
		_save()
		return
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return
	var settings = save_file.get_var()
	if settings is Dictionary:
		tutorial_enabled = bool(settings.get("tutorial_enabled", true))
		screen_shake_enabled = bool(settings.get("screen_shake_enabled", true))
		game_speed = clampf(float(settings.get("game_speed", 1.0)), 1.0, 3.0)
		vsync_enabled = bool(settings.get("vsync_enabled", false))
		music_volume = clampf(float(settings.get("music_volume", 0.20)), 0.0, 1.0)
		sfx_volume = clampf(float(settings.get("sfx_volume", 0.35)), 0.0, 1.0)
		display_mode = clampi(
			int(settings.get("display_mode", DISPLAY_MODE_WINDOWED)),
			DISPLAY_MODE_FULLSCREEN,
			DISPLAY_MODE_BORDERLESS
		)
		var saved_resolution = settings.get("resolution", detect_device_resolution())
		var loaded_resolution := detect_device_resolution()
		if saved_resolution is Vector2i:
			loaded_resolution = saved_resolution
		elif saved_resolution is Vector2:
			loaded_resolution = Vector2i(saved_resolution)
		var snapped_resolution := snap_resolution_to_preset(loaded_resolution)
		resolution = snapped_resolution
		last_character_selection_id = String(settings.get("last_character_selection_id", ""))
		_apply_display_settings()
		_apply_vsync()
		if snapped_resolution != loaded_resolution:
			_save()
		return
	_apply_display_settings()
	_apply_vsync()


static func set_screen_shake_enabled(value: bool) -> void:
	ensure_loaded()
	if screen_shake_enabled == value:
		return
	screen_shake_enabled = value
	_save()


static func set_game_speed(value: float) -> void:
	ensure_loaded()
	var new_speed := clampf(value, 1.0, 3.0)
	if is_equal_approx(game_speed, new_speed):
		return
	game_speed = new_speed
	_save()


static func set_music_volume(value: float) -> void:
	ensure_loaded()
	var new_volume := clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, new_volume):
		return
	music_volume = new_volume
	_save()


static func set_sfx_volume(value: float) -> void:
	ensure_loaded()
	var new_volume := clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, new_volume):
		return
	sfx_volume = new_volume
	_save()


static func set_vsync_enabled(value: bool) -> void:
	ensure_loaded()
	if vsync_enabled == value:
		return
	vsync_enabled = value
	_apply_vsync()
	_save()


static func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)


static func set_display_mode(value: int) -> void:
	ensure_loaded()
	var new_mode := clampi(value, DISPLAY_MODE_FULLSCREEN, DISPLAY_MODE_BORDERLESS)
	if display_mode == new_mode:
		return
	display_mode = new_mode
	_apply_display_settings()
	_save()


static func set_resolution(value: Vector2i) -> void:
	ensure_loaded()
	if resolution == value:
		return
	resolution = value
	if display_mode == DISPLAY_MODE_WINDOWED:
		_apply_windowed_resolution()
	_save()


static func _apply_display_settings() -> void:
	match display_mode:
		DISPLAY_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_windowed_resolution()
			# Decorations are often still 0 the frame we leave fullscreen. Refit once they exist.
			_queue_windowed_resolution_refresh()
		DISPLAY_MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


static func _queue_windowed_resolution_refresh() -> void:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var scene_tree := tree as SceneTree
		if not scene_tree.process_frame.is_connected(_apply_windowed_resolution):
			scene_tree.process_frame.connect(_apply_windowed_resolution, CONNECT_ONE_SHOT)


static func _apply_windowed_resolution() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := _get_fitted_windowed_size(usable)
	DisplayServer.window_set_size(window_size)
	# Windows may still clip a window that does not fit. If that happens, scale again from the real client size.
	var actual_size := DisplayServer.window_get_size()
	if actual_size != window_size:
		window_size = _scale_resolution_to_fit(resolution, actual_size)
		DisplayServer.window_set_size(window_size)
	_center_window_in_usable_rect(usable)


## Fits the saved preset into the usable desktop, including title bar and borders.
## Scales both axes together so the window stays 16:9. Independent clamping causes side black bars.
static func _get_fitted_windowed_size(usable: Rect2i) -> Vector2i:
	var decoration := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	decoration = Vector2i(maxi(decoration.x, 0), maxi(decoration.y, 0))
	var max_client := Vector2i(
		maxi(usable.size.x - decoration.x, 1),
		maxi(usable.size.y - decoration.y, 1)
	)
	return _scale_resolution_to_fit(resolution, max_client)


## Uniformly scales a preset so it fits inside max_size without changing its aspect ratio.
static func _scale_resolution_to_fit(requested: Vector2i, max_size: Vector2i) -> Vector2i:
	if requested.x <= 0 or requested.y <= 0:
		return requested
	if requested.x <= max_size.x and requested.y <= max_size.y:
		return requested
	var scale := minf(float(max_size.x) / float(requested.x), float(max_size.y) / float(requested.y))
	# Height is usually the limit because of the taskbar and title bar. Derive width from it to keep 16:9.
	var fitted_height := maxi(1, roundi(float(requested.y) * scale))
	var fitted_width := maxi(1, roundi(float(fitted_height) * float(requested.x) / float(requested.y)))
	if fitted_width > max_size.x:
		fitted_width = max_size.x
		fitted_height = maxi(1, roundi(float(fitted_width) * float(requested.y) / float(requested.x)))
	return Vector2i(fitted_width, fitted_height)


## Centers the decorated window inside the usable desktop, not the full screen.
static func _center_window_in_usable_rect(usable: Rect2i) -> void:
	var decorated_size := DisplayServer.window_get_size_with_decorations()
	var extra := usable.size - decorated_size
	var origin := usable.position + Vector2i(extra.x >> 1, extra.y >> 1)
	origin.x = clampi(origin.x, usable.position.x, usable.position.x + maxi(usable.size.x - decorated_size.x, 0))
	origin.y = clampi(origin.y, usable.position.y, usable.position.y + maxi(usable.size.y - decorated_size.y, 0))
	DisplayServer.window_set_position(origin)


## Clears progression-related preferences while keeping audio, display, and control options.
static func reset_progression_preferences() -> void:
	ensure_loaded()
	tutorial_enabled = true
	last_character_selection_id = ""
	_save()


static func set_last_character_selection_id(character_id: String) -> void:
	ensure_loaded()
	if last_character_selection_id == character_id:
		return
	last_character_selection_id = character_id
	_save()


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
		"screen_shake_enabled": screen_shake_enabled,
		"game_speed": game_speed,
		"vsync_enabled": vsync_enabled,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"display_mode": display_mode,
		"resolution": resolution,
		"last_character_selection_id": last_character_selection_id,
	}
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("GameSettings: failed to write %s" % SAVE_PATH)
		return
	save_file.store_var(settings)
