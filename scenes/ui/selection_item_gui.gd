class_name SelectionItemGui
extends VBoxContainer

@onready var icon: TextureRect = $IconPanel/Icon
@onready var label: Label = $TextPanel/VBoxContainer/Label
@onready var description: Label = $TextPanel/VBoxContainer/Description

func set_item(item: Dictionary) -> void:
	icon.texture = item.icon
	label.text = item.label
	description.text = item.description

func _on_select_button_pressed() -> void:
	GameManager.available_buidling_packs -= 1
	# TODO instantiate building card
	GameManager.buildings_pack.clear()
