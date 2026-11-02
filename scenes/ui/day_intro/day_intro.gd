extends Control

## Brief center-screen day announcement after the merchant. Flies into the run HUD's day label,
## which only shows the new day once this lands. RoundFlow holds the first Hour until it finishes.

const IN_DURATION := 0.24
const HOLD_DURATION := 0.5
const FLY_DURATION := 0.5
# Short beat after the merge so the HUD pop reads before play resumes.
const SETTLE_DURATION := 0.16
const INTRO_SCALE := Vector2(0.7, 0.7)
const FLY_ARC_HEIGHT := 70.0

@onready var _band: TextureRect = %Band
@onready var _day_label: Label = %DayLabel

var _day := 0
var _tween: Tween


func _ready() -> void:
	hide()
	add_to_group(InputManager.MENU_GROUP)
	EventBus.day_intro_requested.connect(_on_day_intro_requested)


## InputManager menu hook. Gameplay input waits until the day has landed.
func is_gamepad_menu_active() -> bool:
	return visible


## InputManager menu hook. Nothing here takes focus.
func focus_default() -> void:
	pass


func _on_day_intro_requested(day: int) -> void:
	_day = day
	_day_label.text = "%s %d" % [GameTerms.DAY, day]
	_day_label.pivot_offset = _day_label.size * 0.5
	_day_label.position = (size - _day_label.size) * 0.5
	_day_label.scale = INTRO_SCALE
	_day_label.modulate.a = 0.0
	_day_label.show()
	_band.modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	AudioManager.play_sfx(UISounds.CARD_REVEAL)

	var intro_in := IN_DURATION / GameManager.game_speed
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_band, "modulate:a", 1.0, intro_in)
	_tween.tween_property(_day_label, "modulate:a", 1.0, intro_in)
	_tween.tween_property(_day_label, "scale", Vector2.ONE, intro_in).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_tween.chain().tween_interval(HOLD_DURATION / GameManager.game_speed)
	_tween.chain().tween_callback(_fly_to_hud)


func _fly_to_hud() -> void:
	var target := get_tree().get_first_node_in_group("run_day_label") as Label
	if target == null:
		_land()
		return

	var start := _day_label.position
	var destination := target.get_global_rect().get_center() - _day_label.size * 0.5
	var end_scale := Vector2.ONE * (
		float(target.get_theme_font_size("font_size")) / float(_day_label.get_theme_font_size("font_size"))
	)
	var duration := FLY_DURATION / GameManager.game_speed
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(
		func(t: float) -> void:
			_day_label.position = start.lerp(destination, t) + Vector2(0.0, -sin(t * PI) * FLY_ARC_HEIGHT)
			_day_label.scale = Vector2.ONE.lerp(end_scale, t),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_band, "modulate:a", 0.0, duration * 0.7)
	_tween.chain().tween_callback(_land)


func _land() -> void:
	_day_label.hide()
	EventBus.day_intro_landed.emit(_day)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(SETTLE_DURATION / GameManager.game_speed)
	_tween.tween_callback(_finish)


func _finish() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	EventBus.day_intro_finished.emit()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
