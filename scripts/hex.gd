class_name Hex
extends Node

 # Instead of the map being a mix of tiles of types, the terrian type would determine the entire map type
 # which would determine what resources appear on the map
 # Example: Forest map would have a high wood weight
enum TerrainType { FIELDS, FOREST, MOUNTAIN, SNOW, WATER, SWAMP, CURSED }

var _terrain_type: TerrainType
var _coordinates: Vector2i = Vector2i(0, 0)

#var resources = ["berries", "wheat", "wood", "stone", "water", "sheep"]

var resource_1: ResourceData
var resource_2: ResourceData

var tile_resources = []

var coordinates: Vector2i:
	get:
		return _coordinates
		
func _init(coords: Vector2i) -> void:
	_coordinates = coords
	#generate_resources()


func get_tile_data() -> void:
	pass


#func generate_resources() -> void:
	#resources.shuffle()  # Randomize the order of the array
	#tile_resources = resources.slice(0, 2)  # Get the first 2 items
