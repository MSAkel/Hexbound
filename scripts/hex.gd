class_name Hex
extends Node

# CURSED: Timed event. Unresolved = bad. Resolved = good.
# ENCAMPMENT: Occupoed by a camp. Can be resolved through bargain
# RUINS: ?
enum SpecialTileState { NONE, CURSED, ENCAMPMENT, RUINS }
 # Instead of the map being a mix of tiles of types, the terrian type would determine the entire map type
 # which would determine what resources appear on the map
 # Example: Forest map would have a high wood weight
enum TerrainType { FIELDS, FOREST, MOUNTAIN, SNOW, WATER, SWAMP }
var terrain_type: TerrainType
var _coordinates: Vector2i = Vector2i(0, 0)
var explored: bool = false
var active_rune: RuneData
var special_state: SpecialTileState = SpecialTileState.NONE
var curse: CurseEvent

# The minerals which the tile will contain.
var minerals: Array[MineralUI] = []

var coordinates: Vector2i:
	get:
		return _coordinates
		
func _init(coords: Vector2i) -> void:
	_coordinates = coords

func get_tile_data() -> void:
	pass

func on_explore() -> void:
	if explored:
		match terrain_type:
			TerrainType.FIELDS:
				GameManager.fire_essence += 1
			TerrainType.FOREST:
				GameManager.nature_essence += 1
			TerrainType.MOUNTAIN:
				GameManager.storm_essence += 1
			TerrainType.SNOW:
				GameManager.ice_essence += 1

# func activate_tile() -> void:
func generate_gold() -> int:
	# check for any perks/runes which could impact gold production
	return 5

# func generate_mineral(mineral: MineralUI) -> int:
# 	pass
