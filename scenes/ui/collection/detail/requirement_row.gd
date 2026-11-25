class_name CollectionRequirementRow
extends HBoxContainer

## One Station requirement: an optional "different" marker, a fixed-size icon slot and the text
## ("2 Meats"). The icon slot keeps its size, so placeholder kind icons can be swapped later.

@onready var _different: Control = $Different
@onready var _icon: TextureRect = $IconSlot/Icon
@onready var _label: Label = $Label


func setup(icon_texture: Texture2D, text: String, different: bool) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = icon_texture
	_label.text = text
	_different.visible = different
