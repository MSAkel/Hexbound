class_name SegmentPathOverlay
extends Node2D

## Flame trails along each course in fire order.
## Shown with the segment-links layout toggle or Tab peek.

const PATH_Z_INDEX := 22
const STREAM_FLAME := preload("res://assets/particles/flame/flame_06.png")
const CAP_FLAME := preload("res://assets/particles/flame/flame_01.png")
const BOARD_PARTICLE_SCALE := float(HexTileMap.HEX_TEXTURE_SIZE.x) / 221.0

const EDGE_LIFETIME := 0.95
const CAP_LIFETIME := 1.25
const EDGE_SCALE_MIN := 0.14 * BOARD_PARTICLE_SCALE
const EDGE_SCALE_MAX := 0.22 * BOARD_PARTICLE_SCALE
const EDGE_STREAM_SPREAD := 5.0
const CAP_SCALE_MIN := 0.14 * BOARD_PARTICLE_SCALE
const CAP_SCALE_MAX := 0.24 * BOARD_PARTICLE_SCALE
const SINGLE_SCALE_MIN := 0.18 * BOARD_PARTICLE_SCALE
const SINGLE_SCALE_MAX := 0.3 * BOARD_PARTICLE_SCALE
const PARTICLES_PER_PIXEL := 1.0 / (22.0 * BOARD_PARTICLE_SCALE)
const EDGE_AMOUNT_MIN := 8
const EDGE_AMOUNT_MAX := 16
const CAP_VISIBILITY_HALF := 180.0 * BOARD_PARTICLE_SCALE

var _map: HexTileMap
var _order_view_active: bool = false
var _additive_material: CanvasItemMaterial
var _flame_stream_ramp: GradientTexture1D
var _flame_cap_ramp: GradientTexture1D
var _flame_scale_curve: CurveTexture


func setup(map: HexTileMap) -> void:
	_map = map
	z_index = PATH_Z_INDEX
	visible = false
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flame_stream_ramp = _make_flame_stream_ramp()
	_flame_cap_ramp = _make_flame_cap_ramp()
	_flame_scale_curve = _make_flame_scale_curve()


func set_visible_for_order_view(active: bool) -> void:
	# Hover refreshes call this every cell change. Restart only on a real on/off flip.
	if _order_view_active == active:
		return
	_order_view_active = active
	visible = active
	_set_tree_emitting(self, active)


func rebuild() -> void:
	for child in get_children():
		child.free()
	if _map == null:
		return

	var segments := _map.get_ordered_segments()
	for coords_list in segments:
		if coords_list.is_empty():
			continue
		_add_segment_visuals(coords_list)

	_set_tree_emitting(self, _order_view_active)


func _add_segment_visuals(coords_list: Array) -> void:
	var points := PackedVector2Array()
	for coords: Vector2i in coords_list:
		points.append(_map.base_layer.map_to_local(coords))

	var group := Node2D.new()
	add_child(group)

	var start := points[0]
	if points.size() == 1:
		# Lone tile is both start and end. A small burner stands in for the missing stream.
		group.add_child(_make_cap_particles(start, Vector2.UP, true))
		return

	for i in range(points.size() - 1):
		group.add_child(_make_edge_particles(points[i], points[i + 1]))

	var end := points[points.size() - 1]
	var last_dir := (end - points[points.size() - 2]).normalized()
	if last_dir == Vector2.ZERO:
		last_dir = Vector2.UP

	group.add_child(_make_cap_particles(start, last_dir, false))
	group.add_child(_make_cap_particles(end, last_dir, false))


func _make_edge_particles(from_pos: Vector2, to_pos: Vector2) -> GPUParticles2D:
	var delta := to_pos - from_pos
	var length := delta.length()
	var stream_speed := length / EDGE_LIFETIME
	var particles := _make_particles()
	# Emit at the course tail and flow toward the next spot in fire order.
	particles.position = from_pos
	particles.rotation = delta.angle() - PI * 0.5
	particles.amount = clampi(int(length * PARTICLES_PER_PIXEL), EDGE_AMOUNT_MIN, EDGE_AMOUNT_MAX)
	particles.lifetime = EDGE_LIFETIME
	particles.preprocess = EDGE_LIFETIME
	particles.texture = STREAM_FLAME
	var stream_half_width := 20.0 * BOARD_PARTICLE_SCALE
	particles.visibility_rect = Rect2(
		-stream_half_width,
		-8.0 * BOARD_PARTICLE_SCALE,
		stream_half_width * 2.0,
		length + 16.0 * BOARD_PARTICLE_SCALE
	)
	particles.randomness = 0.12

	var process_mat := ParticleProcessMaterial.new()
	# flame_06 reads as a directional tongue when it points along travel.
	process_mat.particle_flag_align_y = true
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(
		5.0 * BOARD_PARTICLE_SCALE,
		2.0 * BOARD_PARTICLE_SCALE,
		1.0
	)
	process_mat.direction = Vector3(0.0, 1.0, 0.0)
	process_mat.spread = EDGE_STREAM_SPREAD
	process_mat.initial_velocity_min = stream_speed * 0.92
	process_mat.initial_velocity_max = stream_speed * 1.04
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 0.0
	process_mat.damping_max = 1.5 * BOARD_PARTICLE_SCALE
	process_mat.angular_velocity_min = 0.0
	process_mat.angular_velocity_max = 0.0
	process_mat.scale_min = EDGE_SCALE_MIN
	process_mat.scale_max = EDGE_SCALE_MAX
	process_mat.scale_curve = _flame_scale_curve
	process_mat.color_ramp = _flame_stream_ramp
	particles.process_material = process_mat
	return particles


func _make_cap_particles(center: Vector2, direction: Vector2, is_single: bool) -> GPUParticles2D:
	var particles := _make_particles()
	particles.position = center
	particles.rotation = direction.angle() - PI * 0.5
	particles.amount = 9 if is_single else 8
	particles.lifetime = CAP_LIFETIME
	particles.preprocess = CAP_LIFETIME
	particles.texture = CAP_FLAME
	var cap_half := CAP_VISIBILITY_HALF
	particles.visibility_rect = Rect2(-cap_half, -cap_half, cap_half * 2.0, cap_half * 2.0)
	particles.randomness = 0.45

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = (10.0 if is_single else 5.0) * BOARD_PARTICLE_SCALE
	process_mat.direction = Vector3(0.0, -1.0, 0.0)
	process_mat.spread = 68.0
	process_mat.gravity = Vector3(0.0, -18.0 * BOARD_PARTICLE_SCALE, 0.0)
	process_mat.damping_min = 8.0 * BOARD_PARTICLE_SCALE
	process_mat.damping_max = 16.0 * BOARD_PARTICLE_SCALE
	process_mat.initial_velocity_min = 6.0 * BOARD_PARTICLE_SCALE
	process_mat.initial_velocity_max = 16.0 * BOARD_PARTICLE_SCALE
	process_mat.angular_velocity_min = -70.0
	process_mat.angular_velocity_max = 70.0
	process_mat.scale_min = SINGLE_SCALE_MIN if is_single else CAP_SCALE_MIN
	process_mat.scale_max = SINGLE_SCALE_MAX if is_single else CAP_SCALE_MAX
	process_mat.scale_curve = _flame_scale_curve
	process_mat.color_ramp = _flame_cap_ramp
	particles.process_material = process_mat
	return particles


func _make_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.material = _additive_material
	particles.local_coords = true
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.35
	particles.emitting = false
	return particles


func _make_flame_stream_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.1, 0.38, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.98, 0.82, 0.0),
		Color(1.0, 0.9, 0.42, 0.92),
		Color(1.0, 0.52, 0.08, 0.78),
		Color(0.82, 0.18, 0.03, 0.32),
		Color(0.28, 0.06, 0.02, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _make_flame_cap_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.08, 0.3, 0.65, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 0.88, 0.0),
		Color(1.0, 0.95, 0.55, 0.98),
		Color(1.0, 0.58, 0.1, 0.82),
		Color(0.9, 0.24, 0.04, 0.38),
		Color(0.22, 0.05, 0.02, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _make_flame_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.22, 1.0))
	curve.add_point(Vector2(1.0, 0.12))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = curve
	return curve_texture


func _set_tree_emitting(node: Node, active: bool) -> void:
	if node is GPUParticles2D:
		var particles: GPUParticles2D = node
		particles.emitting = active
		if active:
			particles.restart()
	for child in node.get_children():
		_set_tree_emitting(child, active)
