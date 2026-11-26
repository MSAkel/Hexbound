class_name CollectionDetailTag
extends PanelContainer

## A pill in the detail header: a dark "kind" tag (DISH, RARE) or a tan "place" tag (USA, 6 Gold).
## Both looks are set in the scene.

enum Look { KIND, PLACE }

@export var kind_style: StyleBox
@export var kind_font_color: Color
@export var place_style: StyleBox
@export var place_font_color: Color

@onready var _label: Label = $Label


func setup(text: String, look: Look) -> void:
	if not is_node_ready():
		await ready
	_label.text = text.to_upper()
	var is_kind := look == Look.KIND
	add_theme_stylebox_override("panel", kind_style if is_kind else place_style)
	_label.add_theme_color_override("font_color", kind_font_color if is_kind else place_font_color)
