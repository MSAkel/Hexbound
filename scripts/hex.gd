class_name Hex
extends Node

enum SpecialTileState { NONE, CURSED, BANDITS, MYSTERY }
 # Instead of the map being a mix of tiles of types, the terrian type would determine the entire map type
 # which would determine what resources appear on the map
 # Example: Forest map would have a high wood weight
enum TerrainType { FIELDS, FOREST, MOUNTAIN, SNOW, WATER, SWAMP, CURSED }
var terrain_type: TerrainType
var _coordinates: Vector2i = Vector2i(0, 0)
# var mineral_1: MineralData
# var mineral_2: MineralData
var explored: bool = false
var active_rune: RuneData
var special_tile_state: SpecialTileState = SpecialTileState.NONE


# The minerals which the tile will contain.
# To replace mineral_1 and mineral_2
var minerals: Array[Mineral] = []

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
