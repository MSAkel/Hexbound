class_name Mineral
extends Node2D

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var mineral_data: MineralData

@onready var icon: Sprite2D = $Icon
@onready var label: Label = $Label

func _ready() -> void:
	# Set the icon and label to the mineral data
	icon.texture = mineral_data.icon
	label.text = mineral_data.name
