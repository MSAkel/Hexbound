class_name BuildingUI
extends Control

@onready var building_button: TextureButton = $Container/BuildingButton

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

func _on_ruins_button_pressed() -> void:
	pass


func setup(building: Building) -> void:
	if not is_node_ready():
		await ready
	
	building_button.texture_normal = building.icon
	
	
	
	
