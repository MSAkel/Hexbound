class_name CollectionRecipeSlot
extends PanelContainer

## One recipe entry in the "In the kitchen" panel: a named card (solid outline) or any card of a
## kind (dashed outline). Both looks are set in the scene.

@export var named_style: StyleBox
@export var named_font_color: Color
@export var any_style: StyleBox
@export var any_font_color: Color

@onready var _icon: TextureRect = $Row/Icon
@onready var _label: Label = $Row/Label


func setup(icon_texture: Texture2D, text: String, is_any: bool) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = icon_texture
	_icon.visible = icon_texture != null
	_label.text = text
	add_theme_stylebox_override("panel", any_style if is_any else named_style)
	_label.add_theme_color_override("font_color", any_font_color if is_any else named_font_color)
