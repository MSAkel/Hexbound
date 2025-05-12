class_name Hex
extends Node

enum TerrainType { FIELDS, FOREST, MOUNTAIN, SNOW, WATER, SWAMP, CURSED }

var _terrain_type: TerrainType
var _coordinates: Vector2i = Vector2i(0, 0)

var coordinates: Vector2i:
	get:
		return _coordinates
		
func _init(coords: Vector2i) -> void:
	_coordinates = coords
