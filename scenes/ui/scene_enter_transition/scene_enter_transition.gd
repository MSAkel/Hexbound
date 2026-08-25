class_name SceneEnterTransition
extends CanvasLayer

const HOLD_DURATION := 1.5
const FADE_DURATION := 0.85
const RUNE_FLOAT_DISTANCE := 12.0
const RUNE_FLOAT_DURATION := 0.9
const RUNE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/icons/runes/support/unstable_rune.png"),
	preload("res://assets/icons/runes/support/radiant_link.png"),
	preload("res://assets/icons/runes/hybrid/unstable_concoction.png"),
	preload("res://assets/icons/runes/modifier/gold_extraction.png"),
	preload("res://assets/icons/runes/production/golden_ratio.png"),
	preload("res://assets/icons/runes/production/overcharge.png"),
]

@onready var fade: ColorRect = $Fade
@onready var rune: TextureRect = $Rune


## Holds on a randomly chosen floating rune, then reveals the newly loaded scene.
func play() -> void:
	show()
	rune.texture = RUNE_TEXTURES.pick_random()
	rune.pivot_offset = rune.size * 0.5
	rune.modulate.a = 0.0
	rune.scale = Vector2(0.78, 0.78)

	var reveal_tween := create_tween()
	reveal_tween.set_ease(Tween.EASE_OUT)
	reveal_tween.set_trans(Tween.TRANS_BACK)
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(rune, "modulate:a", 1.0, 0.35)
	reveal_tween.tween_property(rune, "scale", Vector2.ONE, 0.45)

	var start_y := rune.position.y
	var float_tween := create_tween().set_loops()
	float_tween.set_trans(Tween.TRANS_SINE)
	float_tween.set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(rune, "position:y", start_y - RUNE_FLOAT_DISTANCE, RUNE_FLOAT_DURATION)
	float_tween.tween_property(rune, "position:y", start_y + RUNE_FLOAT_DISTANCE, RUNE_FLOAT_DURATION)

	await get_tree().create_timer(HOLD_DURATION).timeout

	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.set_parallel(true)
	fade_tween.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
	fade_tween.tween_property(rune, "modulate:a", 0.0, FADE_DURATION * 0.7)
	fade_tween.tween_property(rune, "scale", Vector2(1.12, 1.12), FADE_DURATION)
	await fade_tween.finished

	float_tween.kill()
	queue_free()
