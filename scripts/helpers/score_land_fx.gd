class_name ScoreLandFx
extends RefCounted

## Subtle centered scale and tilt when a score number lands.

const DURATION := 0.3
const NUMBER_SCALE_MIN := 1.02
const NUMBER_SCALE_MAX := 1.055
const PANEL_SCALE_PEAK := 1.015
const TILT_MIN_DEG := 1.0
const TILT_MAX_DEG := 3.0


## Gently scales and tilts a score label around the visible text center.
static func play_number_land(host: Node, label: Label, intensity: float) -> Tween:
	if label == null or not is_instance_valid(label):
		return null

	_center_pivot_on_text(label)
	label.scale = Vector2.ONE
	label.rotation_degrees = 0.0

	var peak_scale := lerpf(NUMBER_SCALE_MIN, NUMBER_SCALE_MAX, intensity)
	var peak_tilt := lerpf(TILT_MIN_DEG, TILT_MAX_DEG, intensity) * (-1.0 if randf() > 0.5 else 1.0)
	var duration := DURATION / GameManager.game_speed

	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(peak_scale, peak_scale), duration * 0.38).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "rotation_degrees", peak_tilt, duration * 0.38).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, duration * 0.62).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	tween.tween_property(label, "rotation_degrees", 0.0, duration * 0.62).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	return tween


## Very subtle panel pulse. Pivot stays at the panel center.
static func play_panel_pulse(host: Node, panel: Control) -> Tween:
	if panel == null or not is_instance_valid(panel):
		return null

	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE

	var duration := DURATION / GameManager.game_speed
	var tween := host.create_tween()
	tween.tween_property(panel, "scale", Vector2(PANEL_SCALE_PEAK, PANEL_SCALE_PEAK), duration * 0.35).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, duration * 0.65).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	return tween


## Right-aligned score labels fill extra width. Pivot on the glyph box, not the control rect.
static func refresh_text_pivot(label: Label) -> void:
	_center_pivot_on_text(label)


static func _center_pivot_on_text(label: Label) -> void:
	var text_size := label.get_minimum_size()
	if label.size.x <= 0.0 or label.size.y <= 0.0:
		label.pivot_offset = label.size * 0.5
		return

	if text_size.x <= 0.0:
		text_size.x = label.size.x
	if text_size.y <= 0.0:
		text_size.y = label.size.y

	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT:
			label.pivot_offset = Vector2(label.size.x - text_size.x * 0.5, label.size.y * 0.5)
		HORIZONTAL_ALIGNMENT_CENTER:
			label.pivot_offset = Vector2(label.size.x * 0.5, label.size.y * 0.5)
		_:
			label.pivot_offset = Vector2(text_size.x * 0.5, label.size.y * 0.5)
