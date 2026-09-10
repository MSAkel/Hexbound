class_name CardIcon
extends Control

## Reusable card face. Hex shelf plus subject icon as two TextureRects, not a baked composite.
## Use this wherever you only need the picture, hand cards, inspect panels, lists.
## Board tokens that sit on hexes use CardIconUI, which embeds this scene.

## Authored reference size for one board hex token. Hand and inspect hosts scale this down.
const REFERENCE_SIZE := Vector2(256, 256)
## Fraction inset on each side so pixel-art subjects sit inside the hex silhouette.
## 16px of a 112px board token, which is an 80px subject box.
const SUBJECT_HEX_INSET := 16.0 / 112.0

@export var hex_ingredients: Texture2D
@export var hex_kitchenware: Texture2D
@export var hex_utility: Texture2D
@export var hex_dish: Texture2D

@onready var _hex: TextureRect = $Hex
# Subject inset for tile cards lives in card_icon.tscn. Non-tile cards expand to the full control.
@onready var _subject: TextureRect = $Subject


func setup(card: Card) -> void:
	if not is_node_ready():
		await ready
	if card == null:
		show_empty(FeastDisplay.PLACEHOLDER_ICON)
		return
	if card is TileCard:
		_hex.texture = _hex_for_tile_card(card as TileCard)
		_hex.show()
		_apply_subject_layout(true)
		_subject.texture = card.icon if card.icon != null else FeastDisplay.PLACEHOLDER_ICON
		_subject.show()
		return
	_hex.hide()
	_apply_subject_layout(false)
	_subject.texture = card.icon if card.icon != null else FeastDisplay.PLACEHOLDER_ICON
	_subject.show()


## Empty hex inspect, or any single texture that should fill the control.
func show_empty(texture: Texture2D) -> void:
	if not is_node_ready():
		await ready
	_hex.texture = texture
	_hex.show()
	_subject.hide()


func _hex_for_tile_card(card: TileCard) -> Texture2D:
	match card.type:
		TileCard.TileCardType.KITCHENWARE:
			return hex_kitchenware
		TileCard.TileCardType.INGREDIENT:
			return hex_ingredients
		TileCard.TileCardType.MEAL:
			return hex_dish if hex_dish != null else hex_kitchenware
	return hex_ingredients


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
