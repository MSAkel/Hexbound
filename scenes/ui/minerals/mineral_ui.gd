class_name MineralUI
extends Node2D

@export var mineral: Mineral : set = set_mineral 

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
# var mineral_data: MineralData

@onready var icon: Sprite2D = $Icon
@onready var label: Label = $Label

# func _ready() -> void:
# 	icon.texture = mineral_data.icon
# 	label.text = mineral_data.name

func set_mineral(new_mineral: Mineral) -> void:
	if not is_node_ready():
		await ready
	
	mineral = new_mineral
	icon.texture = mineral.icon
	label.text = mineral.name
