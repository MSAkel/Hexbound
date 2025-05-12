class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
@onready var hex_border_layer: TileMapLayer = $HexBorderLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer


@export var width := 25
@export var height := 25

func _ready() -> void:
	generate_terrain()
		
		
func generate_terrain() -> void:
	for x in width:
		for y in height:
			base_layer.set_cell(Vector2i(x, y), 0, Vector2i(1,1))
