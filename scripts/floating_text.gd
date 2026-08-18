class_name FloatingText
extends Node2D

@onready var label: RichTextLabel = $Label
@onready var timer: Timer = $Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

const RISE_DISTANCE := 60.0
const RISE_DURATION := 1.0
## Segment score floats use a shorter rise than tile-activation floats.
const SEGMENT_RISE_DURATION := 0.32
const GROW_MERGE_DURATION := 0.22
const SHRINK_MERGE_DURATION := 0.15


func _ready() -> void:
	if not timer.timeout.is_connected(_on_Timer_timeout):
		timer.timeout.connect(_on_Timer_timeout)


func set_text(text: String, color: Color = Color.WHITE) -> void:
	if not is_node_ready():
		await ready

	label.bbcode_enabled = false
	label.text = text
	_apply_label_style(color, ScoreReadoutStyle.parse_amount(text))
	audio_stream_player_2d.play()


## One readout of "score x multiplier" with aqua score and plum multiplier.
func set_segment_product(score: int, multiplier: int) -> void:
	if not is_node_ready():
		await ready

	var score_html := Color.AQUA.to_html(false)
	var mult_html := Color.PLUM.to_html(false)
	label.bbcode_enabled = true
	label.text = "[color=#%s]%s[/color] x [color=#%s]%s[/color]" % [
		score_html,
		CountingNumber.format_int(score),
		mult_html,
		CountingNumber.format_int(multiplier),
	]
	_apply_label_style(Color.WHITE, score * multiplier)
	audio_stream_player_2d.play()


func _apply_label_style(color: Color, amount_for_size: int) -> void:
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	_set_font_size(float(ScoreReadoutStyle.font_size_for_score(amount_for_size)))
	_center_label_pivot()


## Plays the original rise-and-fade, then frees the node.
func play_float_and_free() -> void:
	timer.stop()
	timer.wait_time = RISE_DURATION / GameManager.game_speed
	timer.start()
	animation_player.speed_scale = GameManager.game_speed
	animation_player.play("float")


## Rises without fading so a follow-up merge can keep the digits visible.
func play_rise() -> void:
	timer.stop()
	animation_player.stop()
	label.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(
		label,
		"position",
		Vector2(0, -RISE_DISTANCE),
		SEGMENT_RISE_DURATION / GameManager.game_speed
	)
	await tween.finished


## Flies the readout toward a world-space point. Grow lands as the main score. Shrink absorbs into it.
func merge_into(target_world: Vector2, grow: bool, target_font_size: int) -> void:
	timer.stop()
	animation_player.stop()
	label.modulate = Color.WHITE
	_center_label_pivot()

	var duration := (GROW_MERGE_DURATION if grow else SHRINK_MERGE_DURATION) / GameManager.game_speed
	var dest := global_position + (target_world - get_visual_global_center())
	var start_font := float(label.get_theme_font_size("normal_font_size"))

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", dest, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT if grow else Tween.EASE_IN
	)
	if grow:
		tween.tween_method(_set_font_size, start_font, float(target_font_size), duration)
		tween.tween_property(label, "scale", Vector2.ONE, duration)
	else:
		tween.tween_property(self, "scale", Vector2(0.08, 0.08), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 0.0, duration * 0.9)
	await tween.finished


func get_visual_global_center() -> Vector2:
	return label.global_position + (label.size * label.scale) * 0.5


func _set_font_size(value: float) -> void:
	label.add_theme_font_size_override("normal_font_size", int(round(value)))
	_center_label_pivot()


func _center_label_pivot() -> void:
	label.pivot_offset = label.size * 0.5


func _on_Timer_timeout() -> void:
	queue_free()
