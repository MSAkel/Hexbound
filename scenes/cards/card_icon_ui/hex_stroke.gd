class_name HexStroke
extends Line2D

## Draws the token's rounded-square outline from the top, clockwise, as progress goes from 0 to 1.

@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_rebuild()

const DRAW_DURATION := 0.38
const FADE_DURATION := 0.22
# Inset from the token control so the stroke sits on the hex edge.
const RADIUS_INSET := 1.0
const REST_WIDTH := 3.0
const REST_COLOR := Color(1.0, 0.86, 0.42, 0.95)
# Cyan outline so the firing tile does not share the gold segment-reveal flash.
const ACTIVATION_GLOW_COLOR := Color(0.42, 0.95, 1.0, 1.0)
const ACTIVATION_GLOW_WIDTH := 5.0
const ACTIVATION_GLOW_PEAK_WIDTH := 7.0
# Retrigger orange. Distinct from cyan self-fire and gold garnish.
const TRIGGER_LINK_RING_COLOR := Color(1.0, 0.58, 0.12, 0.92)
const TRIGGER_LINK_RING_WIDTH := 4.0
const TRIGGER_LINK_RING_PEAK_WIDTH := 6.0
const CHAINED_ACTIVATION_GLOW_COLOR := Color(1.0, 0.62, 0.18, 1.0)
const CHAINED_ACTIVATION_GLOW_WIDTH := 4.0
const CHAINED_ACTIVATION_GLOW_PEAK_WIDTH := 6.0

var _draw_tween: Tween
var _trigger_link_ring_active := false


func _ready() -> void:
	clear_points()
	hide()


func play_clockwise_draw() -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()

	_restore_rest_stroke()
	modulate.a = 1.0
	progress = 0.0
	show()

	_draw_tween = create_tween()
	_draw_tween.tween_property(self, "progress", 1.0, DRAW_DURATION / GameManager.game_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_draw_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION / GameManager.game_speed)
	_draw_tween.tween_callback(_on_glow_finished)


## Full hex ring that pulses while this rune is the tile currently activating.
func play_activation_glow(duration: float) -> void:
	_play_pulse_glow(
		ACTIVATION_GLOW_COLOR,
		ACTIVATION_GLOW_WIDTH,
		ACTIVATION_GLOW_PEAK_WIDTH,
		duration,
		true
	)


## Sustained ring on the source rune while its queued triggers resolve.
func start_trigger_link_ring() -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()

	_trigger_link_ring_active = true
	progress = 1.0
	default_color = TRIGGER_LINK_RING_COLOR
	width = TRIGGER_LINK_RING_WIDTH
	modulate = Color(1.2, 1.2, 1.2, 1.0)
	show()

	var pulse := 0.35 / GameManager.game_speed
	_draw_tween = create_tween()
	_draw_tween.set_loops()
	_draw_tween.tween_property(self, "width", TRIGGER_LINK_RING_PEAK_WIDTH, pulse).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_draw_tween.tween_property(self, "width", TRIGGER_LINK_RING_WIDTH, pulse).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


func stop_trigger_link_ring() -> void:
	_trigger_link_ring_active = false
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()
	_draw_tween = null
	hide()
	progress = 0.0
	_restore_rest_stroke()


func play_chained_activation_glow(duration: float) -> void:
	if _trigger_link_ring_active:
		return
	_play_pulse_glow(
		CHAINED_ACTIVATION_GLOW_COLOR,
		CHAINED_ACTIVATION_GLOW_WIDTH,
		CHAINED_ACTIVATION_GLOW_PEAK_WIDTH,
		duration,
		true
	)


func _play_pulse_glow(
	glow_color: Color,
	glow_width: float,
	peak_width: float,
	duration: float,
	fade_out: bool
) -> void:
	if _draw_tween != null and _draw_tween.is_valid():
		_draw_tween.kill()

	progress = 1.0
	default_color = glow_color
	width = glow_width
	modulate = Color(1.35, 1.35, 1.35, 1.0)
	show()

	var scaled := maxf(duration, 0.12) / GameManager.game_speed
	var pop := scaled * 0.35
	var hold := scaled * 0.4
	var fade := scaled * 0.25

	_draw_tween = create_tween()
	_draw_tween.tween_property(self, "width", peak_width, pop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_draw_tween.tween_property(self, "width", glow_width, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if fade_out:
		_draw_tween.parallel().tween_property(self, "modulate:a", 0.0, fade).set_delay(pop + hold * 0.5)
	_draw_tween.tween_callback(_on_glow_finished)


func _on_glow_finished() -> void:
	if _trigger_link_ring_active:
		return
	hide()
	progress = 0.0
	_restore_rest_stroke()


func _restore_rest_stroke() -> void:
	width = REST_WIDTH
	default_color = REST_COLOR
	modulate = Color.WHITE


## Walks the outline by arc length so the rounded corners do not speed up the stroke.
func _rebuild() -> void:
	clear_points()
	if progress <= 0.0:
		return

	var vertices := _outline_vertices()
	# A full ring closes itself. Repeating the first point would double-paint the seam as a bright dot.
	closed = progress >= 1.0
	if closed:
		for vertex: Vector2 in vertices:
			add_point(vertex)
		return
	vertices.append(vertices[0])
	var perimeter := 0.0
	for i in vertices.size() - 1:
		perimeter += vertices[i].distance_to(vertices[i + 1])
	var remaining := perimeter * progress

	add_point(vertices[0])
	for i in vertices.size() - 1:
		var edge := vertices[i].distance_to(vertices[i + 1])
		if remaining >= edge:
			add_point(vertices[i + 1])
			remaining -= edge
			continue
		if edge > 0.0:
			add_point(vertices[i].lerp(vertices[i + 1], remaining / edge))
		return


## Rounded square that traces the CardIcon token edge, starting top-center and going clockwise.
func _outline_vertices() -> PackedVector2Array:
	var parent_control := get_parent() as Control
	var center := Vector2.ZERO
	if parent_control != null and parent_control.size != Vector2.ZERO:
		center = parent_control.size * 0.5
	var radius := minf(center.x, center.y)
	return HexShape.rounded_square(center, CardIcon.token_half_extent(radius) - RADIUS_INSET)
