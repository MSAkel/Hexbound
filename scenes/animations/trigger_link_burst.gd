class_name TriggerLinkBurst
extends Node2D

## Moves a tight spark head along the exact source-to-target line, then pops on arrival.

const SPARK_TEXTURE := preload("res://assets/particles/spark/spark_02.png")
const IMPACT_TEXTURE := preload("res://assets/particles/light/light_02.png")
const TRAVEL_DURATION := 0.14
const CLEANUP_DELAY := 0.32
const HEAD_COLOR := Color(1.0, 0.72, 0.24, 1.0)
const TRAIL_COLOR := Color(1.0, 0.62, 0.18, 1.0)
const IMPACT_COLOR := Color(1.0, 0.78, 0.32, 1.0)


static func spawn(parent: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var burst: TriggerLinkBurst = load("res://scenes/animations/trigger_link_burst.gd").new()
	parent.add_child(burst)
	burst.play(from_pos, to_pos)


func play(from_pos: Vector2, to_pos: Vector2) -> void:
	var delta := to_pos - from_pos
	var distance := delta.length()
	if distance < 1.0:
		queue_free()
		return

	position = from_pos

	var carrier := Node2D.new()
	carrier.rotation = delta.angle()
	add_child(carrier)

	var head := _make_head_particles()
	var trail := _make_trail_particles()
	carrier.add_child(head)
	carrier.add_child(trail)

	head.emitting = true
	trail.emitting = true
	head.restart()
	trail.restart()

	var travel_time := TRAVEL_DURATION / GameManager.game_speed
	var tween := create_tween()
	tween.tween_property(carrier, "position", delta, travel_time).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if not is_instance_valid(self):
		return

	head.emitting = false
	trail.emitting = false

	var impact := _make_impact_particles()
	impact.position = delta
	add_child(impact)
	impact.restart()
	impact.emitting = true

	await get_tree().create_timer(CLEANUP_DELAY / GameManager.game_speed).timeout
	if is_instance_valid(self):
		queue_free()


func _make_head_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.z_index = 13
	particles.local_coords = true
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.0
	particles.amount = 3
	particles.lifetime = 0.1
	particles.texture = SPARK_TEXTURE
	particles.visibility_rect = Rect2(-64, -64, 128, 128)
	particles.material = _make_additive_material()

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 2.0
	process_mat.direction = Vector3(1.0, 0.0, 0.0)
	process_mat.spread = 0.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.0
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.22
	process_mat.scale_max = 0.28
	process_mat.color_ramp = _make_color_ramp(HEAD_COLOR, 0.08)
	particles.process_material = process_mat
	return particles


func _make_trail_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.z_index = 12
	particles.local_coords = true
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.0
	particles.amount = 5
	particles.lifetime = 0.11
	particles.preprocess = 0.05
	particles.texture = SPARK_TEXTURE
	particles.visibility_rect = Rect2(-128, -128, 256, 256)
	particles.material = _make_additive_material()

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = Vector3(-1.0, 0.0, 0.0)
	process_mat.spread = 4.0
	process_mat.initial_velocity_min = 8.0
	process_mat.initial_velocity_max = 16.0
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 24.0
	process_mat.damping_max = 32.0
	process_mat.scale_min = 0.1
	process_mat.scale_max = 0.16
	process_mat.color_ramp = _make_color_ramp(TRAIL_COLOR, 0.06)
	particles.process_material = process_mat
	return particles


func _make_impact_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.z_index = 14
	particles.local_coords = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.0
	particles.amount = 8
	particles.lifetime = 0.18
	particles.texture = IMPACT_TEXTURE
	particles.visibility_rect = Rect2(-96, -96, 192, 192)
	particles.material = _make_additive_material()

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 4.0
	process_mat.direction = Vector3(0.0, -1.0, 0.0)
	process_mat.spread = 55.0
	process_mat.initial_velocity_min = 18.0
	process_mat.initial_velocity_max = 34.0
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 28.0
	process_mat.damping_max = 36.0
	process_mat.scale_min = 0.16
	process_mat.scale_max = 0.28
	process_mat.color_ramp = _make_color_ramp(IMPACT_COLOR, 0.05)
	particles.process_material = process_mat
	return particles


func _make_additive_material() -> CanvasItemMaterial:
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return canvas_material


func _make_color_ramp(base_color: Color, fade_tail: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	gradient.add_point(0.2, Color(base_color.r, base_color.g, base_color.b, 0.95))
	gradient.add_point(1.0 - fade_tail, Color(base_color.r, base_color.g, base_color.b, 0.35))
	gradient.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp
