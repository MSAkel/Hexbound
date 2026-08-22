class_name TurnScoreDisplay
extends Control

## Single accumulating turn-score readout used during the post-turn segment reveal.

@onready var turn_score_label: RichTextLabel = $TurnScoreLabel

const PUNCH_DURATION := 0.22
const TILT_OUT_DURATION := 0.08
const TILT_BACK_DURATION := 0.14
const MERGE_DURATION := 0.2
const MERGE_LEAD_IN := 0.06
const BASE_SCREEN_SHAKE := 6.0
const MAX_SCREEN_SHAKE := 28.0
const BASE_TEXT_SHAKE := 4.0
const MAX_TEXT_SHAKE := 20.0
const SHAKE_DURATION := 0.28

var _score_counter: CountingNumber
var _punch_tween: Tween
var _merge_tween: Tween
var _label_rest_position: Vector2 = Vector2.ZERO
var _text_shake_timer: float = 0.0
var _text_shake_duration: float = 0.0
var _text_shake_strength: float = 0.0
var _rest_anchors := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_rest_position = turn_score_label.position
	_score_counter = CountingNumber.for_rich_text_label(
		self,
		turn_score_label,
		true,
		_on_counted_score
	)
	_capture_rest_layout()
	_reset_visual_state()
	set_process(false)
	hide()


func _process(delta: float) -> void:
	if _text_shake_timer <= 0.0:
		set_process(false)
		return

	_text_shake_timer = max(_text_shake_timer - delta, 0.0)
	if _text_shake_timer <= 0.0:
		_stop_text_shake()
		return

	var falloff : float = _text_shake_timer / max(_text_shake_duration, 0.001)
	var amplitude := _text_shake_strength * falloff
	turn_score_label.position = _label_rest_position + Vector2(
		randf_range(-amplitude, amplitude),
		randf_range(-amplitude, amplitude)
	)


## Shows the readout on the first segment, then counts up to the new running total.
func present_running_total(new_total: int) -> void:
	if not visible:
		_reset_visual_state()
		_score_counter.snap_to(0)
		show()

	var intensity := ScoreReadoutStyle.intensity_for_score(new_total)
	_play_impact_effects(intensity)
	var count_tween := _score_counter.play(new_total)
	if count_tween != null:
		await count_tween.finished

	if _punch_tween != null and _punch_tween.is_valid() and _punch_tween.is_running():
		await _punch_tween.finished


## Flies the readout into the round-info panel, collapsing faster on the left, then hides it.
func play_merge_into_round_info() -> void:
	if not visible:
		return

	_stop_text_shake()
	_kill_tweens()

	await get_tree().create_timer(MERGE_LEAD_IN / GameManager.game_speed).timeout

	var duration := MERGE_DURATION / GameManager.game_speed
	var start_global := global_position
	top_level = true
	global_position = start_global

	# Pin the right edge so the left side of the digits collapses first.
	pivot_offset = Vector2(size.x, size.y * 0.5)
	var pivot_global := global_position + pivot_offset
	var target := _get_round_info_target()
	var destination := global_position + (target - pivot_global)

	_merge_tween = create_tween()
	_merge_tween.set_parallel(true)
	_merge_tween.tween_property(self, "global_position", destination, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# X scale finishes sooner so the left edge disappears before the right.
	_merge_tween.tween_property(self, "scale:x", 0.02, duration * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_merge_tween.tween_property(self, "scale:y", 0.18, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_merge_tween.tween_property(self, "modulate:a", 0.0, duration * 0.85).set_ease(Tween.EASE_IN)
	await _merge_tween.finished

	_reset_visual_state()
	hide()


func _play_impact_effects(intensity: float) -> void:
	_center_pivot()
	_start_text_shake(intensity)
	_shake_screen(intensity)
	_play_punch_and_tilt(intensity)


func _play_punch_and_tilt(intensity: float) -> void:
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()

	# Punch scale is a short bounce. Persistent size lives on the font, not this scale.
	rotation = 0.0
	scale = Vector2.ONE

	var punch_scale := 1.08 + intensity * 0.18
	var tilt_degrees := (5.0 + intensity * 8.0) * (1.0 if randf() < 0.5 else -1.0)
	var punch_duration := PUNCH_DURATION / GameManager.game_speed
	var tilt_out := TILT_OUT_DURATION / GameManager.game_speed
	var tilt_back := TILT_BACK_DURATION / GameManager.game_speed

	_punch_tween = create_tween()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(self, "scale", Vector2(punch_scale, punch_scale), punch_duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "rotation_degrees", tilt_degrees, tilt_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_punch_tween.chain()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, punch_duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_punch_tween.tween_property(self, "rotation_degrees", 0.0, tilt_back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Shows the overlay already holding value, used when the first segment float becomes this display.
func appear_from_handoff(value: int) -> void:
	_restore_rest_layout()
	_center_pivot()
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	_score_counter.snap_to(value)
	show()
	_play_impact_effects(ScoreReadoutStyle.intensity_for_score(value))


func get_label_center_canvas() -> Vector2:
	return turn_score_label.get_global_rect().get_center()


func _on_counted_score(as_int: int) -> void:
	turn_score_label.add_theme_font_size_override(
		"normal_font_size",
		ScoreReadoutStyle.font_size_for_score(as_int)
	)
	turn_score_label.add_theme_color_override(
		"default_color",
		ScoreReadoutStyle.color_for_score(as_int)
	)


func _shake_screen(intensity: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	var strength := lerpf(BASE_SCREEN_SHAKE, MAX_SCREEN_SHAKE, intensity)
	camera.shake(strength, SHAKE_DURATION)


func _start_text_shake(intensity: float) -> void:
	_text_shake_strength = lerpf(BASE_TEXT_SHAKE, MAX_TEXT_SHAKE, intensity)
	_text_shake_duration = SHAKE_DURATION / GameManager.game_speed
	_text_shake_timer = _text_shake_duration
	set_process(true)


func _stop_text_shake() -> void:
	_text_shake_timer = 0.0
	set_process(false)
	turn_score_label.position = _label_rest_position


func _get_round_info_target() -> Vector2:
	var panel := get_tree().get_first_node_in_group("round_info_panel") as Control
	if panel == null:
		return get_viewport_rect().position

	# Score lives on the run-status HUD. Find by name so layout tweaks do not break the merge.
	var score_label := panel.find_child("ScoreThisRound", true, false) as Control
	if score_label != null:
		return score_label.get_global_rect().get_center()
	return panel.get_global_rect().get_center()


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _capture_rest_layout() -> void:
	_rest_anchors = {
		"anchor_left": anchor_left,
		"anchor_top": anchor_top,
		"anchor_right": anchor_right,
		"anchor_bottom": anchor_bottom,
		"offset_left": offset_left,
		"offset_top": offset_top,
		"offset_right": offset_right,
		"offset_bottom": offset_bottom,
	}


func _restore_rest_layout() -> void:
	top_level = false
	anchor_left = _rest_anchors.get("anchor_left", 0.5)
	anchor_top = _rest_anchors.get("anchor_top", 0.5)
	anchor_right = _rest_anchors.get("anchor_right", 0.5)
	anchor_bottom = _rest_anchors.get("anchor_bottom", 0.5)
	offset_left = _rest_anchors.get("offset_left", 0.0)
	offset_top = _rest_anchors.get("offset_top", 0.0)
	offset_right = _rest_anchors.get("offset_right", 0.0)
	offset_bottom = _rest_anchors.get("offset_bottom", 0.0)


func _kill_tweens() -> void:
	if _score_counter != null:
		_score_counter.kill()
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	if _merge_tween != null and _merge_tween.is_valid():
		_merge_tween.kill()
	_punch_tween = null
	_merge_tween = null


func _reset_visual_state() -> void:
	_kill_tweens()
	_stop_text_shake()
	_restore_rest_layout()
	_center_pivot()
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	if _score_counter != null:
		_score_counter.snap_to(0)
	turn_score_label.text = ""
	turn_score_label.add_theme_font_size_override("normal_font_size", ScoreReadoutStyle.MIN_FONT_SIZE)
	turn_score_label.add_theme_color_override("default_color", ScoreReadoutStyle.COLOR_WHITE)
