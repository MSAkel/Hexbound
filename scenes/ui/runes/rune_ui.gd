class_name RuneUI
extends Control

@onready var ruins_button: TextureButton = $Container/RuinsButton

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

func _on_ruins_button_pressed() -> void:
	pass


func setup(rune: Rune) -> void:
	if not is_node_ready():
		await ready
	
	ruins_button.texture_normal = rune.icon
	
	
	
	
