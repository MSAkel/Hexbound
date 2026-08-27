class_name SegmentPathOverlay
extends Node2D

## Soft trace-particle chains along each segment in trigger order.
## Shown with the order/segments layout or Tab peek.

const PATH_Z_INDEX := 22
const TRACE_PATH := preload("res://assets/particles/trace/trace_04.png")
const START_LIGHT := preload("res://assets/particles/light/light_03.png")
const END_TWIRL := preload("res://assets/particles/twirl/twirl_03.png")

const EDGE_LIFETIME := 1.35
const CAP_LIFETIME := 1.4
const EDGE_SCALE_MIN := 0.14
const EDGE_SCALE_MAX := 0.22
const START_SCALE_MIN := 0.11
const START_SCALE_MAX := 0.17
const END_SCALE_MIN := 0.1
const END_SCALE_MAX := 0.15
const SINGLE_SCALE_MIN := 0.14
const SINGLE_SCALE_MAX := 0.2
const PARTICLES_PER_PIXEL := 1.0 / 26.0
const EDGE_AMOUNT_MIN := 8
const EDGE_AMOUNT_MAX := 18

# Muted hues so neighboring segments do not read as one continuous loop.
const SEGMENT_COLORS: Array[Color] = [
	Color(0.92, 0.78, 0.38, 0.95),
	Color(0.38, 0.72, 0.78, 0.95),
	Color(0.82, 0.52, 0.38, 0.95),
	Color(0.55, 0.72, 0.42, 0.95),
	Color(0.72, 0.48, 0.78, 0.95),
	Color(0.42, 0.58, 0.88, 0.95),
	Color(0.88, 0.62, 0.52, 0.95),
	Color(0.48, 0.78, 0.62, 0.95),
]

var _map: HexTileMap
var _order_view_active: bool = false
var _additive_material: CanvasItemMaterial


func setup(map: HexTileMap) -> void:
	_map = map
	z_index = PATH_Z_INDEX
	visible = false
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func set_visible_for_order_view(active: bool) -> void:
	_order_view_active = active
	visible = active
	_set_tree_emitting(self, active)


func rebuild() -> void:
	for child in get_children():
		child.free()
	if _map == null:
		return

	var segments := _map.get_ordered_segments()
	for segment_index in range(segments.size()):
		var coords_list: Array = segments[segment_index]
		if coords_list.is_empty():
			continue
		_add_segment_visuals(segment_index, coords_list)

	_set_tree_emitting(self, _order_view_active)


func _add_segment_visuals(segment_index: int, coords_list: Array) -> void:
	var color := SEGMENT_COLORS[segment_index % SEGMENT_COLORS.size()]
	var points := PackedVector2Array()
	for coords: Vector2i in coords_list:
		points.append(_map.base_layer.map_to_local(coords))

	var group := Node2D.new()
	add_child(group)

	var start := points[0]
	if points.size() == 1:
		# Lone tile is both start and end. A small shimmer stands in for the missing stream.
		group.add_child(_make_cap_particles(start, Vector2.RIGHT, color, true, true))
		return

	for i in range(points.size() - 1):
		group.add_child(_make_edge_particles(points[i], points[i + 1], color))

	var end := points[points.size() - 1]
	var last_dir := (end - points[points.size() - 2]).normalized()
	if last_dir == Vector2.ZERO:
		last_dir = Vector2.RIGHT

	group.add_child(_make_cap_particles(start, last_dir, color, true, false))
	group.add_child(_make_cap_particles(end, last_dir, color, false, false))


func _make_edge_particles(from_pos: Vector2, to_pos: Vector2, color: Color) -> GPUParticles2D:
	var delta := to_pos - from_pos
	var length := delta.length()
	var particles := _make_particles()
	particles.position = (from_pos + to_pos) * 0.5
	# Trace textures are vertical. Align local Y with the edge.
	particles.rotation = delta.angle() - PI * 0.5
	particles.amount = clampi(int(length * PARTICLES_PER_PIXEL), EDGE_AMOUNT_MIN, EDGE_AMOUNT_MAX)
	particles.lifetime = EDGE_LIFETIME
	particles.preprocess = EDGE_LIFETIME
	particles.texture = TRACE_PATH
	particles.visibility_rect = Rect2(-length, -length, length * 2.0, length * 2.0)

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_align_y = true
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(8.0, length * 0.48, 1.0)
	process_mat.direction = Vector3(0.0, 1.0, 0.0)
	process_mat.spread = 6.0
	process_mat.initial_velocity_min = 18.0
	process_mat.initial_velocity_max = 36.0
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 8.0
	process_mat.damping_max = 16.0
	process_mat.scale_min = EDGE_SCALE_MIN
	process_mat.scale_max = EDGE_SCALE_MAX
	process_mat.color = color
	process_mat.color_ramp = _make_color_ramp(color, 0.12)
	particles.process_material = process_mat
	return particles


func _make_cap_particles(
	center: Vector2,
	direction: Vector2,
	color: Color,
	is_start: bool,
	is_single: bool
) -> GPUParticles2D:
	var particles := _make_particles()
	particles.position = center
	particles.rotation = direction.angle() - PI * 0.5
	particles.amount = 7 if is_start or is_single else 5
	particles.lifetime = CAP_LIFETIME
	particles.preprocess = CAP_LIFETIME
	# Start is a soft light well. End is a spinning twirl so the two roles stay distinct.
	particles.texture = START_LIGHT if is_start or is_single else END_TWIRL
	particles.visibility_rect = Rect2(-180, -180, 360, 360)

	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_disable_z = true
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 8.0 if is_single else 4.0
	process_mat.direction = Vector3(0.0, 1.0, 0.0)
	process_mat.spread = 180.0
	process_mat.gravity = Vector3.ZERO
	process_mat.damping_min = 12.0
	process_mat.damping_max = 22.0
	if is_start or is_single:
		process_mat.initial_velocity_min = 2.0
		process_mat.initial_velocity_max = 8.0
		process_mat.angular_velocity_min = -24.0
		process_mat.angular_velocity_max = 24.0
		process_mat.scale_min = SINGLE_SCALE_MIN if is_single else START_SCALE_MIN
		process_mat.scale_max = SINGLE_SCALE_MAX if is_single else START_SCALE_MAX
	else:
		process_mat.initial_velocity_min = 4.0
		process_mat.initial_velocity_max = 12.0
		process_mat.angular_velocity_min = 40.0
		process_mat.angular_velocity_max = 90.0
		process_mat.scale_min = END_SCALE_MIN
		process_mat.scale_max = END_SCALE_MAX
	process_mat.color = color
	process_mat.color_ramp = _make_color_ramp(color, 0.16)
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


func _make_color_ramp(base_color: Color, fade_tail: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0 - fade_tail, 1.0])
	gradient.colors = PackedColorArray([
		Color(base_color.r, base_color.g, base_color.b, 0.0),
		Color(base_color.r, base_color.g, base_color.b, 0.9),
		Color(base_color.r, base_color.g, base_color.b, 0.45),
		Color(base_color.r, base_color.g, base_color.b, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _set_tree_emitting(node: Node, active: bool) -> void:
	if node is GPUParticles2D:
		var particles: GPUParticles2D = node
		particles.emitting = active
		if active:
			particles.restart()
	for child in node.get_children():
		_set_tree_emitting(child, active)
