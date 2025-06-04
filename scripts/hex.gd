class_name Hex
extends Node

# CURSED: Timed event. Unresolved = bad. Resolved = good.
# ENCAMPMENT: Occupoed by a camp. Can be resolved through bargain
# RUINS: ?
enum SpecialTileState { NONE, CURSED, ENCAMPMENT, RUINS }
enum TerrainType { FIELDS, FOREST, MOUNTAIN, SNOW, WATER, SWAMP }

# Special events UI
var CURSE_UI: PackedScene = preload("res://scenes/events/curse/curse_ui.tscn")
const RUINS_UI: PackedScene = preload("res://scenes/events/ruins/ruins_ui.tscn")
const RUNE_UI: PackedScene = preload("res://scenes/ui/runes/rune_ui.tscn")
const BUILDING_UI: PackedScene = preload("res://scenes/ui/buildings/building_ui.tscn")
const UNEXPLORED_POI: PackedScene = preload("res://scenes/events/unexplored_poi.tscn")

const UNEXPLORED_POI_TEXTURE: Texture2D = preload("res://assets/icons/events/unexplored_poi.png")
const CURSE_POI_TEXTURE: Texture2D = preload("res://assets/icons/events/curse.png")
const RUINS_POI_TEXTURE: Texture2D = preload("res://assets/icons/events/ruins.png")

var curse: CurseUI
var ruins: RuinsUI

var terrain_type: TerrainType
var _coordinates: Vector2i = Vector2i(0, 0)
var explored: bool = false
var active_rune: Rune = null
var active_building: Building = null
var special_state: SpecialTileState = SpecialTileState.NONE
# var minerals: Array[MineralUI] = []

# References to UI elements
# var mineral_ui_scene: PackedScene
var map: HexTileMap
var items_grid: GridContainer

var coordinates: Vector2i:
	get:
		return _coordinates

func _init(coords: Vector2i) -> void:
	_coordinates = coords


func setup(map_ref: Node2D) -> void:
	map = map_ref
	# Create grid container for items
	items_grid = GridContainer.new()
	items_grid.columns = 2
	items_grid.custom_minimum_size = Vector2(60, 60)  # Increased size to accommodate items
	items_grid.position = map.base_layer.map_to_local(coordinates)
	items_grid.anchors_preset = Control.PRESET_CENTER
	items_grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	items_grid.grow_vertical = Control.GROW_DIRECTION_BOTH
	items_grid.add_theme_constant_override("separation", 12)  # Add spacing between items
	map.add_child(items_grid)


func place_building(building: Building) -> void:
	active_building = building
	var new_building_instance: BuildingUI = BUILDING_UI.instantiate()
	new_building_instance.map = map
	new_building_instance.tile = self
	new_building_instance.center_coordinates = coordinates
	
	new_building_instance.setup(building)
	
	# Set size for the building instance
	new_building_instance.custom_minimum_size = Vector2(60, 60)
	new_building_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_building_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Add to grid instead of directly to map
	items_grid.add_child(new_building_instance)
	_reposition_items()

	if building.passive:
		building.activate_passive()


func place_rune(rune: Rune) -> void:
	active_rune = rune
	var new_rune_instance: RuneUI = RUNE_UI.instantiate()
	new_rune_instance.map = map
	new_rune_instance.tile = self
	new_rune_instance.center_coordinates = coordinates

	new_rune_instance.setup(rune)
	
	# Set size for the rune instance
	new_rune_instance.custom_minimum_size = Vector2(60, 60)
	new_rune_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_rune_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Add to grid instead of directly to map
	items_grid.add_child(new_rune_instance)
	_reposition_items()


func apply_special_state() -> void:
	match special_state:
		SpecialTileState.CURSED:
			var curse_instance: CurseUI = CURSE_UI.instantiate()
			curse_instance.map = map
			curse_instance.tile = self
			curse_instance.center_coordinates = coordinates
			curse = curse_instance
			
			# Set size for the curse instance
			curse_instance.custom_minimum_size = Vector2(60, 60)
			curse_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			curse_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			# Add to grid instead of directly to map
			items_grid.add_child(curse_instance)
			_reposition_items()
			
			# Set unexplored POI texture if tile is not explored
			if not explored:
				var unexplore_poi: UnexploredPOI = UNEXPLORED_POI.instantiate()
				unexplore_poi.map = map
				unexplore_poi.center_coordinates = coordinates
				unexplore_poi.tile = self
				unexplore_poi.position = map.base_layer.map_to_local(coordinates)
				map.add_child(unexplore_poi)
				curse_instance.curse_button.hide()
		# SpecialTileState.ENCAMPMENT:
		# 	# TODO: Implement encampment logic
		# 	pass
		SpecialTileState.RUINS:
			var ruins_instance: RuinsUI = RUINS_UI.instantiate() as RuinsUI
			ruins_instance.map = map
			ruins_instance.tile = self
			ruins_instance.center_coordinates = coordinates
			ruins = ruins_instance
			
			# Set size for the ruins instance
			ruins_instance.custom_minimum_size = Vector2(60, 60)
			ruins_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			ruins_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			# Add to grid instead of directly to map
			items_grid.add_child(ruins_instance)
			_reposition_items()
			
			# Set unexplored POI texture if tile is not explored
			if not explored:
				var unexplore_poi: UnexploredPOI = UNEXPLORED_POI.instantiate()
				unexplore_poi.map = map
				unexplore_poi.center_coordinates = coordinates
				unexplore_poi.tile = self
				unexplore_poi.position = map.base_layer.map_to_local(coordinates)
				map.add_child(unexplore_poi)
				ruins_instance.ruins_button.hide()

# Helper function to reposition items in a center-out pattern
func _reposition_items() -> void:
	var items = items_grid.get_children()
	if items.size() == 0:
		return
		
	# Calculate the center position
	var center_x = items_grid.size.x / 2
	var center_y = items_grid.size.y / 2
	
	# Calculate the offset for each item
	var item_size = 60  # Size of each item
	var spacing = 8    # Spacing between items
	
	# Position items in a center-out pattern
	for i in range(items.size()):
		var item = items[i]
		@warning_ignore("integer_division")
		var row = i / 2
		var col = i % 2
		
		# Calculate position relative to center
		var x_offset = (col - 0.5) * (item_size + spacing)
		var y_offset = (row - 0.5) * (item_size + spacing)
		
		# Set the item's position
		@warning_ignore("integer_division")
		item.position = Vector2(
			center_x + x_offset - item_size/2,
			center_y + y_offset - item_size/2
		)


func explore() -> void:
	if not explored:
		explored = true
		#on_explore()
		
		# Remove any unexplored POI
		for child in map.get_children():
			if child is UnexploredPOI and child.tile == self:
				child.queue_free()
		
		if curse != null:
			curse.curse_button.disabled = false
			curse.curse_button.show()
		
		if ruins != null:
			ruins.ruins_button.disabled = false
			ruins.ruins_button.show()

		GameManager.update_explored_tiles_list(self)


func _create_scale_animation(sprite: Sprite2D, duration: float) -> void:
	var tween = sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), duration)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), duration)
	tween.tween_callback(sprite.queue_free)


func _create_resource_animation(resource_type: String, amount: int, vertical_offset: int) -> void:
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
	sprite.self_modulate.a = 0.5
	map.base_layer.add_sibling(sprite, true)

	# Calculate animation duration based on current game speed
	var animation_duration := 0.1 / GameManager.game_speed
	_create_scale_animation(sprite, animation_duration)
	map.create_floating_text(tile_pos + Vector2(0, vertical_offset), "+%s %s" % [amount, resource_type], resource_type == "Gold")
	
# Called by the rune after its effect is triggered
func trigger_building_generation() -> void:
	for resource in active_building.resource_type:
		var total_amount = active_building.generation_amount + active_building.temporary_boost
		_create_resource_animation(resource, total_amount, 0)
	active_building.trigger_building()


func trigger_rune_activation() -> void:
	active_rune.activate_rune(self)
