class_name ScoreBurstFx
extends RefCounted

## Subtle panel background wash when a score lands. Intensity tints the wash, not additive light.

const WASH_DURATION := 0.3


## Briefly warms the panel fill, then eases back to its resting color.
static func play_background_wash(panel: PanelContainer, intensity: float, strong: bool = false) -> void:
	if panel == null or not is_instance_valid(panel):
		return

	var base_style := panel.get_theme_stylebox("panel")
	if base_style == null or not base_style is StyleBoxFlat:
		return

	var style := base_style as StyleBoxFlat
	var resting_bg := style.bg_color
	var resting_border := style.border_color
	var tint := _wash_tint(intensity, strong)
	var peak_strength := lerpf(0.18, 0.38, intensity) * (1.25 if strong else 1.0)
	var peak_bg := resting_bg.lerp(tint, peak_strength)
	var peak_border := resting_border.lerp(tint.darkened(0.12), peak_strength * 0.65)

	var duration := WASH_DURATION / GameManager.game_speed
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(style, "bg_color", peak_bg, duration * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(style, "border_color", peak_border, duration * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(style, "bg_color", resting_bg, duration * 0.68).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tween.tween_property(style, "border_color", resting_border, duration * 0.68).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)


static func _wash_tint(intensity: float, strong: bool) -> Color:
	var parchment := Color(0.98, 0.93, 0.78, 1.0)
	var honey := Color(0.96, 0.84, 0.52, 1.0)
	var amber := Color(0.92, 0.68, 0.34, 1.0)
	var blend := honey.lerp(amber, intensity)
	if strong:
		blend = blend.lerp(Color(0.88, 0.58, 0.28, 1.0), 0.35)
	return parchment.lerp(blend, 0.55 + intensity * 0.35)
