class_name SealHexShine
extends Node2D

## Gold trace particles that travel the hex rim after a segment closes.

const TRACE_STREAK := preload("res://assets/particles/trace/trace_04.png")
const TRACE_GLINT := preload("res://assets/particles/trace/trace_01.png")
const SIDES := 6
# Painted hex is 221x255 inside the 256 rune control. Keep the rim inside that silhouette.
const HEX_TEXTURE_SIZE := Vector2(221, 255)
const RADIUS_SCALE := 0.84
const SHINE_COLOR := Color(1.02, 0.84, 0.38, 0.72)
const EDGE_AMOUNT := 8
const EDGE_LIFETIME := 0.7
const GLINT_AMOUNT := 5
const GLINT_LIFETIME := 0.9

var _additive_material: CanvasItemMaterial
var _edge_particles: Array[GPUParticles2D] = []
var _glint_particles: GPUParticles2D
var _active := false


func _ready() -> void:
	z_index = 8
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	hide()


func start_shine() -> void:
	_active = true
	_rebuild()
	show()
	for particles: GPUParticles2D in _edge_particles:
		particles.emitting = true
		particles.restart()
	if _glint_particles != null:
		_glint_particles.emitting = true
		_glint_particles.restart()


func stop_shine() -> void:
	_active = false
	for particles: GPUParticles2D in _edge_particles:
		particles.emitting = false
	if _glint_particles != null:
		_glint_particles.emitting = false
	hide()


func _rebuild() -> void:
	for child in get_children():
		child.free()
	_edge_particles.clear()
	_glint_particles = null

	var vertices := _hex_vertices()
	if vertices.size() < SIDES:
		return

	for i in SIDES:
		var from_pos := vertices[i]
		var to_pos := vertices[(i + 1) % SIDES]
		var edge := _make_edge_particles(from_pos, to_pos)
		add_child(edge)
		_edge_particles.append(edge)

	_glint_particles = _make_glint_particles()
	add_child(_glint_particles)


func _make_edge_particles(from_pos: Vector2, to_pos: Vector2) -> GPUParticles2D:
	var delta := to_pos - from_pos
	var length := delta.length()
	var particles := _make_particles()
	particles.position = (from_pos + to_pos) * 0.5
	# Trace textures are vertical. Align local Y with this hex edge.
	particles.rotation = delta.angle() - PI * 0.5
	particles.amount = EDGE_AMOUNT
	particles.lifetime = EDGE_LIFETIME
	particles.preprocess = EDGE_LIFETIME * 0.55
	particles.explosiveness = 0.08
	particles.texture = TRACE_STREAK
	particles.visibility_rect = Rect2(-length, -length, length * 2.0, length * 2.0)

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_align_y = true
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Thin box so streaks sit on the edge instead of spraying outward.
	process_mat.emission_box_extents = Vector3(1.0, length * 0.42, 1.0)
	process_mat.direction = Vector3(0.0, 1.0, 0.0)
	process_mat.spread = 0.0
	process_mat.initial_velocity_min = 10.0
	process_mat.initial_velocity_max = 18.0
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 14.0
	process_mat.damping_max = 22.0
	process_mat.scale_min = 0.045
	process_mat.scale_max = 0.07
	process_mat.color = SHINE_COLOR
	process_mat.color_ramp = _make_color_ramp(SHINE_COLOR)
	particles.process_material = process_mat
	return particles


func _make_glint_particles() -> GPUParticles2D:
	var particles := _make_particles()
	var parent_control := get_parent() as Control
	var center := Vector2(128, 128)
	if parent_control != null and parent_control.size != Vector2.ZERO:
		center = parent_control.size * 0.5
	particles.position = center
	particles.amount = GLINT_AMOUNT
	particles.lifetime = GLINT_LIFETIME
	particles.preprocess = GLINT_LIFETIME * 0.4
	particles.explosiveness = 0.0
	particles.texture = TRACE_GLINT
	particles.visibility_rect = Rect2(-180, -180, 360, 360)

	var radius := _hex_radius()
	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_align_y = true
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process_mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	process_mat.emission_ring_height = 1.0
	process_mat.emission_ring_radius = radius
	process_mat.emission_ring_inner_radius = maxf(radius - 2.0, 1.0)
	process_mat.direction = Vector3(0.0, 0.0, 0.0)
	process_mat.spread = 0.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 4.0
	process_mat.angular_velocity_min = -18.0
	process_mat.angular_velocity_max = 18.0
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 18.0
	process_mat.damping_max = 28.0
	process_mat.scale_min = 0.04
	process_mat.scale_max = 0.06
	process_mat.color = SHINE_COLOR
	process_mat.color_ramp = _make_color_ramp(SHINE_COLOR)
	particles.process_material = process_mat
	return particles


func _make_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.material = _additive_material
	particles.local_coords = true
	particles.one_shot = false
	particles.randomness = 0.4
	particles.emitting = false
	return particles


func _make_color_ramp(base_color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(base_color.r, base_color.g, base_color.b, 0.0),
		Color(base_color.r, base_color.g, base_color.b, 0.55),
		Color(base_color.r, base_color.g, base_color.b, 0.32),
		Color(base_color.r, base_color.g, base_color.b, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _hex_radius() -> float:
	# Pointy-top circumradius of the painted hex, then inset so quads stay inside.
	return HEX_TEXTURE_SIZE.y * 0.5 * RADIUS_SCALE


func _hex_vertices() -> PackedVector2Array:
	var vertices := PackedVector2Array()
	var parent_control := get_parent() as Control
	var center := Vector2(128, 128)
	if parent_control != null and parent_control.size != Vector2.ZERO:
		center = parent_control.size * 0.5
	var radius := _hex_radius()
	for i in SIDES:
		var angle := deg_to_rad(-90.0 + float(i) * 60.0)
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return vertices
