class_name CardIcon
extends Control

## Reusable card picture. Flat rounded square in the card type accent plus the subject icon, not a baked composite.
## Use this wherever you only need the picture, hand cards, inspect panels, lists.
## Board tokens that sit on hexes use CardIconUI, which embeds this scene.

## Fraction inset on each side so pixel-art subjects sit inside the hex silhouette.
## 16px of a 112px board token, which is an 80px subject box.
const SUBJECT_HEX_INSET := 16.0 / 112.0
## Hex outline thickness as a fraction of the hex radius. 3.5px on a 112px board token.
const HEX_OUTLINE_RATIO := 3.5 / 56.0
const HEX_OUTLINE_COLOR := Color(0, 0, 0, 1)
## Square token half side as a fraction of the control radius. 46px of 56 sits inside the 104px board tile.
const TOKEN_HALF_RATIO := 46.0 / 56.0

## Off for hosts that draw their own backdrop, such as the card face frame.
@export var show_hex := true

# Set while a tile card is shown. The hex is drawn in _draw so it stays a plain accent fill.
var _draws_hex := false
var _hex_color := Color.WHITE

# Stands in for the whole picture when there is no card to show, such as an empty spot.
@onready var _placeholder: TextureRect = $Placeholder
# Inset inside the hex for tile cards. Fills the whole control otherwise.
@onready var _subject: TextureRect = $Subject


func setup(card: Card) -> void:
	if not is_node_ready():
		await ready
	if card == null:
		show_empty(FeastStatIcons.PLACEHOLDER)
		return
	var in_hex := card is TileCard and show_hex
	_set_drawn_hex(in_hex, CardTypeColors.for_card(card))
	_apply_subject_layout(in_hex)
	_placeholder.hide()
	_subject.texture = card.icon if card.icon != null else FeastStatIcons.PLACEHOLDER
	_subject.show()


## Empty hex inspect, or any single texture that should fill the control.
func show_empty(texture: Texture2D) -> void:
	if not is_node_ready():
		await ready
	_set_drawn_hex(false)
	_subject.hide()
	_placeholder.texture = texture
	_placeholder.show()


func _set_drawn_hex(enabled: bool, color: Color = Color.WHITE) -> void:
	_draws_hex = enabled
	_hex_color = color
	queue_redraw()


## Rounded square centered in the control. Drawn behind the child TextureRects.
func _draw() -> void:
	if not _draws_hex:
		return
	var center := size * 0.5
	var radius := minf(center.x, center.y)
	var outline_width := radius * HEX_OUTLINE_RATIO
	# The outline is stroked along its own center line, so pull the ring in by half its width.
	var corners := HexShape.rounded_square(center, token_half_extent(radius) - outline_width * 0.5)
	draw_colored_polygon(corners, _hex_color)

	# rounded_square starts mid-edge, so closing on the first point leaves no notch at a corner.
	var ring := corners.duplicate()
	ring.append(corners[0])
	draw_polyline(ring, HEX_OUTLINE_COLOR, outline_width, true)


## Half side of the square token for a control of this radius. Shared with HexStroke so the glow traces the token.
static func token_half_extent(radius: float) -> float:
	return radius * TOKEN_HALF_RATIO


func _apply_subject_layout(fits_in_hex: bool) -> void:
	if fits_in_hex:
		_subject.anchor_left = SUBJECT_HEX_INSET
		_subject.anchor_top = SUBJECT_HEX_INSET
		_subject.anchor_right = 1.0 - SUBJECT_HEX_INSET
		_subject.anchor_bottom = 1.0 - SUBJECT_HEX_INSET
	else:
		_subject.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subject.offset_left = 0.0
	_subject.offset_top = 0.0
	_subject.offset_right = 0.0
	_subject.offset_bottom = 0.0
