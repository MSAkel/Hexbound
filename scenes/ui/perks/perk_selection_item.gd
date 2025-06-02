class_name PerkSelectionItem
extends VBoxContainer

signal item_selected(item: Dictionary)

@onready var icon: TextureRect = $IconPanel/Icon
@onready var label: Label = $TextPanel/VBoxContainer/Label
@onready var description: Label = $TextPanel/VBoxContainer/Description

func set_item(item: Dictionary) -> void:
	icon.texture = item.icon
	label.text = item.label
	description.text = item.description


func _on_select_button_pressed() -> void:
	pass # Replace with function body.
