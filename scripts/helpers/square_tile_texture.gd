class_name SquareTileTexture
extends RefCounted

## Rounded-square board tiles drawn in code. Stands in for the old hex PNGs so the board needs no square art.

## Base spot. Dark rim, thin light inner rim, warm top-to-bottom gradient.
const BASE := {
	"fill": Color8(255, 225, 178),
	"fill_bottom": Color8(255, 189, 97),
	"border": Color8(208, 157, 100),
	"border_width": 5,
	"inner_rim": Color8(250, 220, 170),
}
## Staff slot. Same shape as BASE in a cooler, muted tan so the column reads apart from the board.
const STAFF := {
	"fill": Color8(240, 228, 200),
	"fill_bottom": Color8(214, 184, 136),
	"border": Color8(176, 146, 108),
	"border_width": 5,
	"inner_rim": Color8(236, 224, 196),
}
const HOVER := {
	"fill": Color8(171, 195, 96, 128),
	"border": Color8(140, 161, 80),
	"border_width": 3,
}
const CARD_HIGHLIGHT := {
	"fill": Color8(149, 207, 255, 128),
	"border": Color8(178, 225, 255),
	"border_width": 3,
}
const DISABLED := {
	"fill": Color8(27, 27, 40, 38),
	"border": Color8(30, 30, 40, 76),
	"border_width": 3,
}
const FADING_SECTOR := {
	"fill": Color8(255, 134, 30, 76),
	"border": Color8(253, 155, 74),
	"border_width": 3,
}

const CORNER_RADIUS := 10.0
const INNER_RIM_WIDTH := 1.0

static var _cache: Dictionary = {}


## Cached texture for one style at one size.
static func get_texture(style: Dictionary, size: Vector2i) -> ImageTexture:
	var key := [style, size]
	if _cache.has(key):
		return _cache[key]
	var texture := ImageTexture.create_from_image(_draw(style, size))
	_cache[key] = texture
	return texture


static func _draw(style: Dictionary, size: Vector2i) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var fill: Color = style["fill"]
	var fill_bottom: Color = style.get("fill_bottom", fill)
	var border: Color = style["border"]
	var border_width := float(style["border_width"])
	var inner_rim: Variant = style.get("inner_rim")
	var half := Vector2(size) * 0.5
	for y in size.y:
		var row_fill := fill.lerp(fill_bottom, float(y) / maxf(size.y - 1, 1))
		for x in size.x:
			# Signed distance to the rounded-square edge. Negative inside.
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - half).abs()
			var q := p - (half - Vector2(CORNER_RADIUS, CORNER_RADIUS))
			var dist := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - CORNER_RADIUS
			var depth := -dist
			if depth <= 0.0:
				continue
			var color := border
			if depth > border_width:
				color = row_fill
				if inner_rim != null and depth <= border_width + INNER_RIM_WIDTH:
					color = inner_rim
			# Coverage antialias on the outer edge only.
			color.a *= clampf(depth, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return image
