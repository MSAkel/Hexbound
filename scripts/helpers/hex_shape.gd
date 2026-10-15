class_name HexShape
extends RefCounted

## Geometry for board tokens and their outline strokes.
## The board is square now. corners() is kept for any remaining pointy-top hex drawing.

const SIDES := 6
## Corner rounding as a fraction of the half extent. Matches SquareTileTexture's 10px on a 52px half tile.
const SQUARE_CORNER_RATIO := 10.0 / 52.0
const SQUARE_CORNER_SEGMENTS := 4


## Corners of a regular pointy-top hex. Starts at the top and steps clockwise in Godot's y-down space.
static func corners(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SIDES:
		var angle := deg_to_rad(-90.0 + float(i) * 60.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Closed outline of a rounded square. Starts at top-center and steps clockwise in y-down space.
## The first point is not repeated at the end.
static func rounded_square(center: Vector2, half_extent: float) -> PackedVector2Array:
	var radius := half_extent * SQUARE_CORNER_RATIO
	var inner := half_extent - radius
	var points := PackedVector2Array([center + Vector2(0, -half_extent)])
	# Corner arc centers clockwise from top-right, with each arc's start angle.
	var arcs := [
		[Vector2(inner, -inner), -90.0],
		[Vector2(inner, inner), 0.0],
		[Vector2(-inner, inner), 90.0],
		[Vector2(-inner, -inner), 180.0],
	]
	for arc: Array in arcs:
		var arc_center: Vector2 = center + arc[0]
		for step in SQUARE_CORNER_SEGMENTS + 1:
			var angle := deg_to_rad(float(arc[1]) + 90.0 * float(step) / SQUARE_CORNER_SEGMENTS)
			points.append(arc_center + Vector2(cos(angle), sin(angle)) * radius)
	return points
