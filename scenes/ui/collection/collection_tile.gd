class_name CollectionTile
extends Button

## One entry in a Collection page's list: icon, name and a small type label. The page gives its
## tiles one ButtonGroup, so exactly one is pressed (the selected tile, drawn with the pressed style).
## Focus selects too, so arrow keys and the d-pad move the selection with no separate focus look.

signal chosen(tile: CollectionTile)

const UNDISCOVERED_NAME := "???"

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _kind_label: Label = %KindLabel

## Index of this entry in its page's list.
var entry_index: int = -1


func _ready() -> void:
	toggled.connect(_on_toggled)
	focus_entered.connect(_on_focus_entered)


func set_entry(icon_texture: Texture2D, display_name: String, kind_text: String) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = icon_texture
	_icon.modulate = Color.WHITE
	_name_label.text = display_name
	_kind_label.text = kind_text.to_upper()
	_kind_label.visible = not kind_text.is_empty()
	tooltip_text = ""


## A hidden entry the player has not found yet: "???", the icon as a dark silhouette, no type label.
func set_undiscovered(icon_texture: Texture2D) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = icon_texture
	_icon.modulate = Color.BLACK
	_name_label.text = UNDISCOVERED_NAME
	_kind_label.visible = false


func select() -> void:
	button_pressed = true


func _on_toggled(pressed: bool) -> void:
	if pressed:
		chosen.emit(self)


func _on_focus_entered() -> void:
	if not button_pressed:
		button_pressed = true
