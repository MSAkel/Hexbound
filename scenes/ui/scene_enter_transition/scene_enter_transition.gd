class_name SceneEnterTransition
extends CanvasLayer

const HOLD_DURATION := 1.5
const FADE_DURATION := 0.85
const ICON_FLOAT_DISTANCE := 12.0
const ICON_FLOAT_DURATION := 0.9

@onready var fade: ColorRect = $Fade
@onready var icon: TextureRect = $Rune

var _float_tween: Tween
var _icon_rest_y: float = 0.0


## Holds on a randomly chosen Feast icon, then reveals the newly loaded scene.
func play() -> void:
	show()
	_prepare_icon()
	fade.modulate.a = 1.0
	icon.modulate.a = 0.0
	icon.scale = Vector2(0.78, 0.78)

	var reveal_tween := create_tween()
	reveal_tween.set_ease(Tween.EASE_OUT)
	reveal_tween.set_trans(Tween.TRANS_BACK)
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(icon, "modulate:a", 1.0, 0.35)
	reveal_tween.tween_property(icon, "scale", Vector2.ONE, 0.45)

	_start_icon_float()
	await get_tree().create_timer(HOLD_DURATION).timeout
	await _play_reveal_fade()
	queue_free()


func _prepare_icon() -> void:
	icon.texture = FeastStatIcons.LOADING_SPLASH.pick_random()
	icon.pivot_offset = icon.size * 0.5


func _start_icon_float() -> void:
	_kill_float()
	_icon_rest_y = icon.position.y
	_float_tween = create_tween().set_loops()
	_float_tween.set_trans(Tween.TRANS_SINE)
	_float_tween.set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(icon, "position:y", _icon_rest_y - ICON_FLOAT_DISTANCE, ICON_FLOAT_DURATION)
	_float_tween.tween_property(icon, "position:y", _icon_rest_y + ICON_FLOAT_DISTANCE, ICON_FLOAT_DURATION)


func _play_reveal_fade() -> void:
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.set_parallel(true)
	fade_tween.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
	fade_tween.tween_property(icon, "modulate:a", 0.0, FADE_DURATION * 0.7)
	fade_tween.tween_property(icon, "scale", Vector2(1.12, 1.12), FADE_DURATION)
	await fade_tween.finished
	_kill_float()


func _kill_float() -> void:
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
		if is_instance_valid(icon):
			icon.position.y = _icon_rest_y
	_float_tween = null
