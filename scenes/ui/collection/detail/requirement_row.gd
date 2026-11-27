class_name CollectionRequirementRow
extends HBoxContainer

## One Station requirement: a fixed-size icon slot and the text ("2 Meats"). The icon slot keeps its
## size, so placeholder kind icons can be swapped later.

@onready var _icon: TextureRect = $IconSlot/Icon
@onready var _label: Label = $Label


func setup(icon_texture: Texture2D, text: String) -> void:
	if not is_node_ready():
		await ready
	_icon.texture = icon_texture
	_label.text = text
