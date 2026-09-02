class_name GameSettings
extends RefCounted

## Persistent player options stored in user://, independent of the current run save.

const SAVE_PATH := "user://game_settings.save"

const DISPLAY_MODE_FULLSCREEN := 0
const DISPLAY_MODE_WINDOWED := 1
const DISPLAY_MODE_BORDERLESS := 2
const DEFAULT_WINDOWED_RESOLUTION := Vector2i(1280, 720)

## When true, the in-run tutorial banner appears the next time a run starts.
static var tutorial_enabled: bool = true
static var screen_shake_enabled: bool = true
static var game_speed: float = 1.0
static var vsync_enabled: bool = false
static var music_volume: float = 0.20
static var sfx_volume: float = 0.35
static var display_mode: int = DISPLAY_MODE_FULLSCREEN
static var resolution: Vector2i = Vector2i(1920, 1080)
## Last character shown on the character selection screen, even if no run was started.
static var last_character_selection_id: String = ""
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
		screen_shake_enabled = bool(settings.get("screen_shake_enabled", true))
		game_speed = clampf(float(settings.get("game_speed", 1.0)), 1.0, 3.0)
		vsync_enabled = bool(settings.get("vsync_enabled", false))
		music_volume = clampf(float(settings.get("music_volume", 0.20)), 0.0, 1.0)
		sfx_volume = clampf(float(settings.get("sfx_volume", 0.35)), 0.0, 1.0)
		display_mode = clampi(
			int(settings.get("display_mode", DISPLAY_MODE_FULLSCREEN)),
			DISPLAY_MODE_FULLSCREEN,
			DISPLAY_MODE_BORDERLESS
		)
		var saved_resolution = settings.get("resolution", Vector2i(1920, 1080))
		if saved_resolution is Vector2i:
			resolution = saved_resolution
		elif saved_resolution is Vector2:
			resolution = Vector2i(saved_resolution)
		last_character_selection_id = String(settings.get("last_character_selection_id", ""))
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
			_shrink_fullscreen_sized_resolution()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_windowed_resolution()
		DISPLAY_MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


static func _apply_windowed_resolution() -> void:
	DisplayServer.window_set_size(resolution)
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var delta := screen_size - resolution
	DisplayServer.window_set_position(
		screen_position + Vector2i(delta.x >> 1, delta.y >> 1)
	)


## A fullscreen-sized saved resolution would make Windowed appear unchanged.
static func _shrink_fullscreen_sized_resolution() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable_size := DisplayServer.screen_get_usable_rect(screen).size
	if resolution.x >= usable_size.x or resolution.y >= usable_size.y:
		resolution = DEFAULT_WINDOWED_RESOLUTION


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
