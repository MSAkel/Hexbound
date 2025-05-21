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
var active_rune: Rune
var special_state: SpecialTileState = SpecialTileState.NONE
var curse: CurseUI
var minerals: Array[MineralUI] = []

# References to UI elements
var mineral_ui_scene: PackedScene
var curse_scene: PackedScene
var map: Node2D  # Reference to the HexTileMap

var coordinates: Vector2i:
	get:
		return _coordinates

func _init(coords: Vector2i) -> void:
	_coordinates = coords

func setup(map_ref: Node2D, mineral_scene: PackedScene, curse_scene_ref: PackedScene) -> void:
	map = map_ref
	mineral_ui_scene = mineral_scene
	curse_scene = curse_scene_ref

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

func generate_gold() -> int:
	# check for any perks/runes which could impact gold production
	return 5

func produce_mineral(mineral_ui: MineralUI) -> int:
	if mineral_ui.mineral.type == Mineral.Type.BERRIES:
		return 5
	elif mineral_ui.mineral.type == Mineral.Type.WOOL:
		return 3
	elif mineral_ui.mineral.type == Mineral.Type.STONE:
		return 3
	elif mineral_ui.mineral.type == Mineral.Type.WOOD:
		return 5
	
	return 5

# Generate minerals UI scene which will be available and displayed on the tile
func generate_minerals(available_minerals: Array[Mineral]) -> void:
	if terrain_type == TerrainType.WATER:
		return
		
	available_minerals.shuffle()
	var tile_minerals: Array[Mineral] = available_minerals.slice(0, 2)
	
	for i in tile_minerals.size():
		var mineral = tile_minerals[i]
		var mineral_ui: MineralUI = mineral_ui_scene.instantiate() as MineralUI
		mineral_ui.map = map
		mineral_ui.center_coordinates = coordinates
		mineral_ui.tile = self
		minerals.append(mineral_ui)
		
		# Base position on the tile
		var base_pos = map.base_layer.map_to_local(coordinates)
		var offset = Vector2((i - (tile_minerals.size() - 1) / 2.0) * 72, -32)
		mineral_ui.position = base_pos + offset
		
		mineral_ui.set_mineral(mineral)
		map.add_child(mineral_ui)
		mineral_ui.hide()

func apply_special_state() -> void:
	match special_state:
		SpecialTileState.CURSED:
			var curse_instance: CurseUI = curse_scene.instantiate() as CurseUI
			curse_instance.map = map
			curse_instance.tile = self
			curse_instance.center_coordinates = coordinates
			curse = curse_instance
			
			curse_instance.position = map.base_layer.map_to_local(coordinates)
			map.add_child(curse_instance)
		SpecialTileState.ENCAMPMENT:
			# TODO: Implement encampment logic
			pass
		SpecialTileState.RUINS:
			# TODO: Implement ruins logic
			pass

func explore() -> void:
	if not explored:
		explored = true
		on_explore()
		
		if curse != null:
			curse.curse_button.disabled = false
			
		for mineral in minerals:
			mineral.show()
			
		GameManager.update_explored_tiles_list(self)

func create_resource_animation(resource_type: String, amount: int, vertical_offset: int) -> void:
	var tile_pos = map.base_layer.map_to_local(coordinates)
	
	# Create and animate tile sprite
	var sprite = Sprite2D.new()
	var atlas_source = map.base_layer.tile_set.get_source(0) as TileSetAtlasSource
	var coords = map.terrain_textures[terrain_type]
	var tile_id = atlas_source.get_tile_at_coords(coords)
	sprite.texture = atlas_source.texture
	sprite.region_enabled = true
	sprite.region_rect = atlas_source.get_tile_texture_region(tile_id)
	sprite.position = tile_pos
	sprite.centered = true
	map.base_layer.add_sibling(sprite, true)
	
	create_scale_animation(sprite, 0.1 / GameManager.game_speed)
	map.create_floating_text(tile_pos + Vector2(0, vertical_offset), "+%s %s" % [amount, resource_type], resource_type == "gold")

func create_scale_animation(sprite: Sprite2D, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), duration)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), duration)
	tween.tween_callback(sprite.queue_free)
