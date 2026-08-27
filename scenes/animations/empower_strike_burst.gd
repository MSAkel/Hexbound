class_name EmpowerStrikeBurst
extends Node2D

## Bolt, Trail, and Impact are GPUParticles2D on this scene. This only aims the carrier and plays them.

@export var travel_duration := 0.18
@export var fall_x_jitter := 28.0

@onready var _carrier: Node2D = $Carrier
@onready var _bolt: GPUParticles2D = $Carrier/Bolt
@onready var _trail: GPUParticles2D = $Carrier/Trail
@onready var _impact: GPUParticles2D = $Impact
@onready var _fall_start: Vector2 = $Carrier.position


func play(target_pos: Vector2) -> void:
	position = target_pos
	# Jitter only on X. Fall height is Carrier's scene position.
	var start_offset := Vector2(
		_fall_start.x + randf_range(-fall_x_jitter, fall_x_jitter),
		_fall_start.y
	)
	_carrier.position = start_offset
	_carrier.rotation = (-start_offset).angle()

	_play_emitter(_bolt)
	_play_emitter(_trail)

	var tween := create_tween()
	tween.tween_property(_carrier, "position", Vector2.ZERO, travel_duration / GameManager.game_speed).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_instance_valid(self):
		return

	_bolt.emitting = false
	_trail.emitting = false
	_play_emitter(_impact)

	await GameManager.create_pauseable_timer(_impact.lifetime / GameManager.game_speed).timeout
	if is_instance_valid(self):
		queue_free()


func _play_emitter(particles: GPUParticles2D) -> void:
	particles.restart()
	particles.emitting = true
