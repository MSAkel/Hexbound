class_name HexShape
extends RefCounted

## Geometry for the pointy-top hexes drawn by board tokens and their outline strokes.

const SIDES := 6


## Corners of a regular pointy-top hex. Starts at the top and steps clockwise in Godot's y-down space.
static func corners(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SIDES:
		var angle := deg_to_rad(-90.0 + float(i) * 60.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
