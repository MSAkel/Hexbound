class_name BuildingSelectionItem
extends VBoxContainer

@onready var icon: TextureRect = $IconPanel/Icon
@onready var label: Label = $TextPanel/VBoxContainer/Label
@onready var description: Label = $TextPanel/VBoxContainer/Description

var building: Building

func set_item(item: Building) -> void:
	building = item
	
	if not is_node_ready():
		await ready

	icon.texture = item.icon
	label.text = item.name
	description.text = item.description


func _on_select_button_pressed() -> void:
	GameManager.available_building_packs -= 1
	GameManager.buildings_pack.clear()
	Events.building_selected.emit(building)
