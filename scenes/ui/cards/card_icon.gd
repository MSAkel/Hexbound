class_name CardIcon
extends Control

## Reusable card face. Hex shelf plus subject icon as two TextureRects, not a baked composite.
## Use this wherever you only need the picture, hand cards, inspect panels, lists.
## Board tokens that sit on hexes use CardIconUI, which embeds this scene.

@export var hex_ingredients: Texture2D
@export var hex_kitchenware: Texture2D
@export var hex_economy: Texture2D
@export var hex_utility: Texture2D

@onready var _hex: TextureRect = $Hex
@onready var _subject: TextureRect = $Subject

# Subject fills more of the hex shelf. Inset is (1 - subject_scale) / 2.
const _SUBJECT_INSET := 0.16


func setup(card: Card) -> void:
	if not is_node_ready():
		await ready
	if card == null:
		show_empty(FeastDisplay.PLACEHOLDER_ICON)
		return
	if card is TileCard:
		_hex.texture = _hex_for_tile_card(card as TileCard)
		_hex.show()
		_set_subject_inset(true)
		_subject.texture = card.icon if card.icon != null else FeastDisplay.PLACEHOLDER_ICON
		_subject.show()
		return
	_hex.hide()
	_set_subject_inset(false)
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
		TileCard.TileCardType.UTILITY:
			return hex_utility
		TileCard.TileCardType.KITCHENWARE:
			return hex_kitchenware
		TileCard.TileCardType.INGREDIENT:
			return hex_ingredients
		TileCard.TileCardType.ECONOMY:
			return hex_economy
	return hex_ingredients


func _set_subject_inset(enabled: bool) -> void:
	if enabled:
		_subject.anchor_left = _SUBJECT_INSET
		_subject.anchor_top = _SUBJECT_INSET
		_subject.anchor_right = 1.0 - _SUBJECT_INSET
		_subject.anchor_bottom = 1.0 - _SUBJECT_INSET
	else:
		_subject.anchor_left = 0.0
		_subject.anchor_top = 0.0
		_subject.anchor_right = 1.0
		_subject.anchor_bottom = 1.0
	_subject.offset_left = 0.0
	_subject.offset_top = 0.0
	_subject.offset_right = 0.0
	_subject.offset_bottom = 0.0
