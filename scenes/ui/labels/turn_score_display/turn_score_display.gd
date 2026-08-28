class_name TurnScoreDisplay
extends Control

## Per-segment Score overlay. Factors appear at the top, morph into the product, then fly into the HUD.

@onready var turn_score_label: RichTextLabel = $TurnScoreLabel
@onready var segment_title: Label = $SegmentTitle

const TILT_OUT_DURATION := 0.08
const TILT_BACK_DURATION := 0.14
const MERGE_DURATION := 0.2
const MERGE_LEAD_IN := 0.12
const BASE_SCREEN_SHAKE := 6.0
const MAX_SCREEN_SHAKE := 28.0
const BASE_TEXT_SHAKE := 4.0
const MAX_TEXT_SHAKE := 20.0
const SHAKE_DURATION := 0.28
## Hold Energy x Mult long enough to read the factors and the Segment N title.
const FACTOR_HOLD_DURATION := 1.05
const TUTORIAL_EQUALS_HOLD := 0.55
## Hold the product before it flies so the player can match Score to its segment.
const PRODUCT_HOLD_DURATION := 0.9
const APPEAR_DURATION := 0.16
const FACTOR_FONT_SCALE := 0.72
## Peak overshoot when Energy x Mult becomes the product.
const MORPH_PUNCH_SCALE := 1.42
const MORPH_SQUASH := Vector2(1.18, 0.72)
const MORPH_SQUASH_DURATION := 0.08
const MORPH_EXPAND_DURATION := 0.18
const MORPH_SETTLE_DURATION := 0.2
const HEX_FADE_IN_DURATION := 0.15
const HEX_FADE_OUT_DURATION := 0.20
## Radius relative to the score font. Keeps the hex smaller than the digits.
const HEX_RADIUS_FROM_FONT := 0.55
## Saturated warm fills. Dark enough that white text plus a black outline stays readable.
const HEX_COLORS: Array[Color] = [
	Color(0.96, 0.42, 0.08, 0.82),
	Color(0.90, 0.28, 0.20, 0.82),
	Color(0.78, 0.36, 0.10, 0.82),
]

var _punch_tween: Tween
var _merge_tween: Tween
var _morph_tween: Tween
var _hex_tween: Tween
var _label_rest_position: Vector2 = Vector2.ZERO
var _text_shake_timer: float = 0.0
var _text_shake_duration: float = 0.0
var _text_shake_strength: float = 0.0
var _rest_anchors := {}
var _hex_visible: bool = false
var _hex_scale: float = 0.0
var _hex_color: Color = HEX_COLORS[0]
var _hex_alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_rest_position = turn_score_label.position
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


func _draw() -> void:
	if not _hex_visible or _hex_alpha <= 0.01 or _hex_scale <= 0.01:
		return

	var center := _hex_center()
	var font_size := float(turn_score_label.get_theme_font_size("normal_font_size"))
	var radius := font_size * HEX_RADIUS_FROM_FONT * _hex_scale
	_draw_hex(center, radius, Color(_hex_color, _hex_alpha))


## Shows Segment N plus Energy x Mult, morphs into the product, then holds for the merge beat.
func present_segment(
	segment_index: int,
	energy: int,
	multiplier: int,
	product: int,
	linger_extra: bool = false
) -> void:
	_reset_visual_state()
	segment_title.text = "Segment %d" % (segment_index + 1)
	segment_title.modulate = Color.WHITE
	_set_score_line(
		"%s x %s" % [CountingNumber.format_int(energy), CountingNumber.format_int(multiplier)],
		float(ScoreReadoutStyle.font_size_for_score(product)) * FACTOR_FONT_SCALE
	)
	show()

	await _play_appear()
	await GameManager.create_pauseable_timer(FACTOR_HOLD_DURATION / GameManager.game_speed).timeout
	if linger_extra:
		await GameManager.create_pauseable_timer(TUTORIAL_EQUALS_HOLD / GameManager.game_speed).timeout

	await _play_product_morph(product)
	await GameManager.create_pauseable_timer(PRODUCT_HOLD_DURATION / GameManager.game_speed).timeout


## Flies the product into the round-info score, collapsing faster on the left, then hides it.
func play_merge_into_round_info() -> void:
	if not visible:
		return

	_stop_text_shake()
	_kill_tweens()

	await GameManager.create_pauseable_timer(MERGE_LEAD_IN / GameManager.game_speed).timeout

	var duration := MERGE_DURATION / GameManager.game_speed
	var start_global := global_position
	top_level = true
	global_position = start_global

	# Pin the right edge so the left side of the digits collapses first.
	pivot_offset = Vector2(size.x, size.y * 0.5)
	var pivot_global := global_position + pivot_offset
	var target := _get_round_info_target()
	var destination := global_position + (target - pivot_global)

	segment_title.modulate.a = 0.0

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


func _play_appear() -> void:
	_center_pivot()
	scale = Vector2(0.82, 0.82)
	modulate.a = 0.0
	rotation = 0.0

	var duration := APPEAR_DURATION / GameManager.game_speed
	_punch_tween = create_tween()
	_punch_tween.set_parallel(true)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "modulate:a", 1.0, duration * 0.7).set_ease(Tween.EASE_OUT)
	await _punch_tween.finished


func _play_product_morph(product: int) -> void:
	var intensity := ScoreReadoutStyle.intensity_for_score(product)
	var start_font := float(turn_score_label.get_theme_font_size("normal_font_size"))
	var end_font := float(ScoreReadoutStyle.font_size_for_score(product))
	var squash_dur := MORPH_SQUASH_DURATION / GameManager.game_speed
	var expand_dur := MORPH_EXPAND_DURATION / GameManager.game_speed
	var settle_dur := MORPH_SETTLE_DURATION / GameManager.game_speed
	var punch_scale := MORPH_PUNCH_SCALE + intensity * 0.16
	var tilt_degrees := (8.0 + intensity * 10.0) * (1.0 if randf() < 0.5 else -1.0)

	_center_pivot()
	_start_hex_burst()
	_play_impact_effects(intensity)

	# Squeeze the factor line so the swap into the product feels like a snap, not a cut.
	_morph_tween = create_tween()
	_morph_tween.tween_property(self, "scale", MORPH_SQUASH, squash_dur).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await _morph_tween.finished

	_set_score_line(CountingNumber.format_int(product), start_font)
	AudioManager.play_sfx(UISounds.CARD_REVEAL)

	_morph_tween = create_tween()
	_morph_tween.set_parallel(true)
	_morph_tween.tween_method(_set_font_size, start_font, end_font, expand_dur).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_morph_tween.tween_property(self, "scale", Vector2(punch_scale, punch_scale), expand_dur).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_morph_tween.tween_property(self, "rotation_degrees", tilt_degrees, TILT_OUT_DURATION / GameManager.game_speed).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)

	_morph_tween.chain()
	_morph_tween.set_parallel(true)
	_morph_tween.tween_property(self, "scale", Vector2.ONE, settle_dur).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_morph_tween.tween_property(self, "rotation_degrees", 0.0, TILT_BACK_DURATION / GameManager.game_speed).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	await _morph_tween.finished


func _play_impact_effects(intensity: float) -> void:
	_center_pivot()
	_start_text_shake(intensity)
	_shake_screen(intensity)


func _start_hex_burst() -> void:
	if _hex_tween != null and _hex_tween.is_valid():
		_hex_tween.kill()

	_hex_visible = true
	_hex_color = HEX_COLORS[randi() % HEX_COLORS.size()]
	_hex_scale = 1.0
	_hex_alpha = 0.0
	queue_redraw()

	var fade_in := HEX_FADE_IN_DURATION / GameManager.game_speed
	var fade_out := HEX_FADE_OUT_DURATION / GameManager.game_speed
	_hex_tween = create_tween()
	_hex_tween.tween_method(_set_hex_alpha, 0.0, 1.0, fade_in).set_ease(Tween.EASE_OUT)
	_hex_tween.tween_method(_set_hex_alpha, 1.0, 0.0, fade_out).set_ease(Tween.EASE_IN)


func _set_hex_alpha(value: float) -> void:
	_hex_alpha = value
	queue_redraw()


func _hex_center() -> Vector2:
	return turn_score_label.get_rect().get_center()


func _draw_hex(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(-90.0 + float(i) * 60.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _set_score_line(text: String, font_size: float) -> void:
	turn_score_label.bbcode_enabled = false
	turn_score_label.text = text
	turn_score_label.add_theme_color_override("default_color", ScoreReadoutStyle.COLOR_WHITE)
	_set_font_size(font_size)


func _set_font_size(value: float) -> void:
	turn_score_label.add_theme_font_size_override("normal_font_size", int(round(value)))


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
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	if _merge_tween != null and _merge_tween.is_valid():
		_merge_tween.kill()
	if _morph_tween != null and _morph_tween.is_valid():
		_morph_tween.kill()
	if _hex_tween != null and _hex_tween.is_valid():
		_hex_tween.kill()
	_punch_tween = null
	_merge_tween = null
	_morph_tween = null
	_hex_tween = null


func _reset_visual_state() -> void:
	_kill_tweens()
	_stop_text_shake()
	_restore_rest_layout()
	_center_pivot()
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	_hex_visible = false
	_hex_scale = 0.0
	_hex_alpha = 0.0
	queue_redraw()
	segment_title.text = ""
	segment_title.modulate = Color.WHITE
	turn_score_label.text = ""
	turn_score_label.add_theme_font_size_override("normal_font_size", ScoreReadoutStyle.MIN_FONT_SIZE)
	turn_score_label.add_theme_color_override("default_color", ScoreReadoutStyle.COLOR_WHITE)
