class_name RuneUI
extends Control

@onready var rune_button: TextureButton = $Container/RuneButton

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

func setup(rune: Rune) -> void:
	if not is_node_ready():
		await ready
	
	rune_button.texture_normal = rune.icon
