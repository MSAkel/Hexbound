class_name LayoutXpBar
extends PanelContainer

## End-of-run layout XP readout. Fills the current level bar, then punches the
## level number and bursts particles whenever the gain crosses a threshold.

const FILL_MIN_DURATION := 0.28
const FILL_MAX_DURATION := 0.72
const PUNCH_SCALE := 1.32
const PUNCH_DURATION := 0.28
const LEVEL_HOLD := 0.08
const REST_COLOR := Color(1.0, 0.9, 0.55, 1.0)
const FLASH_COLOR := Color(1.0, 0.98, 0.86, 1.0)

@onready var level_badge: Control = %LevelBadge
@onready var level_label: Label = %LevelLabel
@onready var gain_label: Label = %GainLabel
@onready var progress_bar: ProgressBar = %XpBar
@onready var progress_label: Label = %ProgressLabel
@onready var level_burst: GPUParticles2D = %LevelBurst

var _play_id: int = 0
var _fill_tween: Tween
var _punch_tween: Tween
var _bar_modulate_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.resized.connect(_center_burst)
	_center_burst()


func play_gain(from_xp: int, xp_gain: int, start_delay: float = 0.4) -> void:
	_play_id += 1
	var play_id := _play_id
	_kill_tweens()
	_apply_visual(from_xp)
	gain_label.text = "+%d XP" % xp_gain if xp_gain > 0 else "No XP gained"

	if xp_gain <= 0:
		return
	# Maxed layouts still show the grant, but there is no bar left to fill.
	if bool(MetaProgressionManager.get_layout_level_progress(from_xp).get("is_max", false)):
		return

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay / _speed()).timeout
		if not _is_play_current(play_id):
			return

	await _animate_to(from_xp, from_xp + xp_gain, play_id)


func _animate_to(from_xp: int, to_xp: int, play_id: int) -> void:
	var current_xp := from_xp
	while current_xp < to_xp:
		if not _is_play_current(play_id):
			return
		var progress: Dictionary = MetaProgressionManager.get_layout_level_progress(current_xp)
		if bool(progress.get("is_max", false)):
			_apply_visual(to_xp)
			return

		var xp_for_level: int = int(progress.get("xp_for_level", 1))
		var xp_into_level: int = int(progress.get("xp_into_level", 0))
		var remaining := xp_for_level - xp_into_level
		# Threshold XP already belongs to the next level, so remaining should stay positive.
		if remaining <= 0:
			current_xp += 1
			_apply_visual(current_xp)
			continue

		var step_end_xp := mini(to_xp, current_xp + remaining)
		var will_level_up := (
			MetaProgressionManager.get_layout_level_for_xp(step_end_xp) > int(progress.get("level", 1))
		)
		var from_ratio := float(progress.get("ratio", 0.0))
		var to_ratio := 1.0 if will_level_up else float(
			MetaProgressionManager.get_layout_level_progress(step_end_xp).get("ratio", 0.0)
		)
		var to_into := xp_for_level if will_level_up else int(
			MetaProgressionManager.get_layout_level_progress(step_end_xp).get("xp_into_level", 0)
		)
		await _tween_fill(from_ratio, to_ratio, xp_into_level, to_into, xp_for_level, play_id)
		if not _is_play_current(play_id):
			return

		current_xp = step_end_xp
		if will_level_up:
			await _play_level_up(current_xp, play_id)
		else:
			_apply_visual(current_xp)

	_apply_visual(to_xp)


func _tween_fill(
	from_ratio: float,
	to_ratio: float,
	from_into: int,
	to_into: int,
	xp_for_level: int,
	play_id: int
) -> void:
	# Duration scales with how much of this level's bar we still have to cover.
	var ratio_delta := absf(to_ratio - from_ratio)
	var duration := clampf(
		FILL_MIN_DURATION + ratio_delta * 0.5,
		FILL_MIN_DURATION,
		FILL_MAX_DURATION
	) / _speed()

	_kill_fill_tween()
	_fill_tween = create_tween()
	_fill_tween.tween_method(
		func(weight: float) -> void:
			if not _is_play_current(play_id):
				return
			progress_bar.value = lerpf(from_ratio, to_ratio, weight)
			var into := int(round(lerpf(float(from_into), float(to_into), weight)))
			progress_label.text = "%d / %d" % [into, xp_for_level],
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _fill_tween.finished


func _play_level_up(new_xp: int, play_id: int) -> void:
	if not _is_play_current(play_id):
		return
	var progress: Dictionary = MetaProgressionManager.get_layout_level_progress(new_xp)
	# Keep the bar full through the punch so the wrap into the next level is readable.
	level_label.text = str(int(progress.get("level", 1)))
	progress_bar.value = 1.0
	if bool(progress.get("is_max", false)):
		progress_label.text = "MAX"
	else:
		progress_label.text = "0 / %d" % int(progress.get("xp_for_level", 1))
	await get_tree().process_frame
	if not _is_play_current(play_id):
		return
	_punch_level()
	_burst_particles()
	_flash_bar()
	AudioManager.play_sfx(UISounds.EMPOWER)
	await get_tree().create_timer((PUNCH_DURATION + LEVEL_HOLD) / _speed()).timeout
	if not _is_play_current(play_id):
		return
	if not bool(progress.get("is_max", false)):
		progress_bar.value = 0.0


func _apply_visual(xp: int) -> void:
	var progress: Dictionary = MetaProgressionManager.get_layout_level_progress(xp)
	level_label.text = str(int(progress.get("level", 1)))
	level_label.modulate = REST_COLOR
	if bool(progress.get("is_max", false)):
		progress_bar.value = 1.0
		progress_label.text = "MAX"
		return
	progress_bar.value = float(progress.get("ratio", 0.0))
	progress_label.text = "%d / %d" % [
		int(progress.get("xp_into_level", 0)),
		int(progress.get("xp_for_level", 1)),
	]


func _punch_level() -> void:
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	# Pivot on the glyph box so the punch scales around the digit, not the leftover label width.
	level_label.pivot_offset = level_label.size * 0.5
	level_label.scale = Vector2.ONE
	level_label.rotation_degrees = 0.0
	level_label.modulate = FLASH_COLOR

	var duration := PUNCH_DURATION / _speed()
	var tilt := 7.0 if randf() > 0.5 else -7.0
	_punch_tween = create_tween()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(level_label, "scale", Vector2(PUNCH_SCALE, PUNCH_SCALE), duration * 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(level_label, "rotation_degrees", tilt, duration * 0.38) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_punch_tween.chain()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(level_label, "scale", Vector2.ONE, duration * 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_punch_tween.tween_property(level_label, "rotation_degrees", 0.0, duration * 0.62) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_punch_tween.tween_property(level_label, "modulate", REST_COLOR, duration * 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _burst_particles() -> void:
	_center_burst()
	level_burst.restart()
	level_burst.emitting = true


func _flash_bar() -> void:
	if _bar_modulate_tween != null and _bar_modulate_tween.is_valid():
		_bar_modulate_tween.kill()
	progress_bar.modulate = Color(1.35, 1.22, 0.85, 1.0)
	_bar_modulate_tween = create_tween()
	_bar_modulate_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.22 / _speed()) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _center_burst() -> void:
	level_burst.position = level_badge.size * 0.5


func _kill_tweens() -> void:
	_kill_fill_tween()
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = null
	if _bar_modulate_tween != null and _bar_modulate_tween.is_valid():
		_bar_modulate_tween.kill()
	_bar_modulate_tween = null
	level_label.scale = Vector2.ONE
	level_label.rotation_degrees = 0.0
	progress_bar.modulate = Color.WHITE


func _kill_fill_tween() -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = null


func _is_play_current(play_id: int) -> bool:
	return play_id == _play_id and is_inside_tree()


func _speed() -> float:
	return maxf(GameManager.game_speed, 0.01)


func _exit_tree() -> void:
	_play_id += 1
	_kill_tweens()
