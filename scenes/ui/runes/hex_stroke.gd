class_name HexStroke
extends Line2D

## Draws a hex outline from the top, clockwise, as progress goes from 0 to 1.

@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_rebuild()

const SIDES := 6
const DRAW_DURATION := 0.38
const FADE_DURATION := 0.22
# Inset from the 256px control so the stroke sits on the hex edge.
const RADIUS_INSET := 1.0

var _draw_tween: Tween


func _ready() -> void:
	clear_points()
	hide()


func play_clockwise_draw() -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()

	modulate.a = 1.0
	progress = 0.0
	show()

	_draw_tween = create_tween()
	_draw_tween.tween_property(self, "progress", 1.0, DRAW_DURATION / GameManager.game_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_draw_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION / GameManager.game_speed)
	_draw_tween.tween_callback(func() -> void:
		hide()
		progress = 0.0
	)


func _rebuild() -> void:
	clear_points()
	if progress <= 0.0:
		return

	var vertices := _hex_vertices()
	var edges_covered := progress * float(SIDES)
	var full_edges := int(edges_covered)
	var edge_frac := edges_covered - float(full_edges)

	for i in range(full_edges + 1):
		add_point(vertices[i % SIDES])

	if full_edges < SIDES:
		var from_i := full_edges % SIDES
		var to_i := (full_edges + 1) % SIDES
		add_point(vertices[from_i].lerp(vertices[to_i], edge_frac))
	elif get_point_count() > 0:
		# Close the loop once the stroke has traveled the full perimeter.
		add_point(vertices[0])


func _hex_vertices() -> PackedVector2Array:
	var vertices: PackedVector2Array = PackedVector2Array()
	var parent_control := get_parent() as Control
	var center := Vector2(128, 128)
	if parent_control != null and parent_control.size != Vector2.ZERO:
		center = parent_control.size * 0.5
	var radius := minf(center.x, center.y) - RADIUS_INSET
	# Start at the top, then step 60 degrees clockwise in Godot's y-down space.
	for i in SIDES:
		var angle := deg_to_rad(-90.0 + float(i) * 60.0)
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return vertices
