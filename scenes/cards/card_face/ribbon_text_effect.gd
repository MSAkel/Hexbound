@tool
class_name RibbonTextEffect
extends RichTextEffect

## Bends one line of text along a curve so it follows ribbon art.
## Wrap the text as [ribbon]Text[/ribbon]. The shape is static, nothing animates.

# Half-width of the window used to read the curve slope for letter tilt.
const SLOPE_STEP := 0.04

## Ribbon center line across the label. X runs left to right, Y is the lift at that point.
@export var curve: Curve
## Pixels of lift where the curve reads 1.
@export var amplitude := 8.0
## Width the curve is stretched over. Match the width of the label that uses this effect.
@export var span := 92.0

# Tag name RichTextLabel looks up for this effect.
var bbcode := "ribbon"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if curve == null or span <= 0.0:
		return true
	# The glyph transform starts at the glyph's own position inside the label.
	var origin := char_fx.transform.origin
	var along := clampf(origin.x / span, 0.0, 1.0)
	# Screen Y points down, so lift and tilt are both negated.
	origin.y -= curve.sample_baked(along) * amplitude
	char_fx.transform = Transform2D(-atan(_slope_at(along)), origin)
	return true


## Rise over run of the ribbon at a point along the label, in pixels.
func _slope_at(along: float) -> float:
	var before := maxf(along - SLOPE_STEP, 0.0)
	var after := minf(along + SLOPE_STEP, 1.0)
	if after <= before:
		return 0.0
	var rise := (curve.sample_baked(after) - curve.sample_baked(before)) * amplitude
	return rise / ((after - before) * span)
