class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var fog_overlay_layer: TileMapLayer = $FogOverlayLayer

# Map size
@export var width: int
@export var height: int

@export var cursed_tiles_count := 3

@export var minerals: Array[Mineral] = []
@onready var terrain_tile_ui: TerrainTileUI = $"../MainUI/TerrainTileUi"

const MINERAL_UI: PackedScene = preload("res://scenes/ui/minerals/mineral_ui.tscn")
const EXPLORE_BUTTON: PackedScene = preload("res://scenes/ui/explore_button.tscn")

var curse_scene: PackedScene = preload("res://scenes/ui/curse_event.tscn")
var hex: Hex
var selected_cell: Vector2i = Vector2i(-1, -1)
 # Dictionary<Vector2i, Hex>
var map_data: Dictionary = {}
# Based off the tilemap textures order. If changed, update the dictionary.
var terrain_textures: Dictionary = {
	hex.TerrainType.FIELDS: Vector2i(0,0),
	hex.TerrainType.FOREST: Vector2i(1,0),
	hex.TerrainType.MOUNTAIN: Vector2i(2,0),
	hex.TerrainType.SNOW: Vector2i(3,0),
	hex.TerrainType.SWAMP: Vector2i(4,0),
	hex.TerrainType.WATER: Vector2i(5,0),
}

func _ready() -> void:
	generate_terrain()
	GameManager.turn_ended.connect(on_turn_ended)
	GameManager.tile_explored.connect(explore_tile)
	# Add initial explore button after terrain generation is complete
	update_explore_buttons()

# Handles listening to tile clicks and selection
func _unhandled_input(event: InputEvent) -> void:
	# only detect input if it hasn't already been consumed
	if event is InputEventMouseButton:
		var map_coords: Vector2i = base_layer.local_to_map(to_local(get_global_mouse_position()))
		# Check if mouse click is within terrain boundaries
		if map_coords.x >= 0 && map_coords.x < width && map_coords.y >= 0 && map_coords.y < height:
			if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
				var h: Hex = map_data[map_coords]
				if h.terrain_type != hex.TerrainType.WATER:
					terrain_tile_ui.set_hex(h)
					
					# Remove the current overlay texture on selecting a different tile
					if map_coords != selected_cell:
						selection_overlay_layer.set_cell(selected_cell, -1)
						
					# Apply overlay tile on selecting a tile
					selection_overlay_layer.set_cell(map_coords, 0, Vector2i(0,0))
					selected_cell = map_coords
		else:
			# Deselect active cell on clicking outside the map
			selection_overlay_layer.set_cell(selected_cell, -1)

func generate_terrain() -> void:
	# Initialize noise maps for terrain features
	var noise_map := []
	var swamp_map := []
	var snow_map := []
	var mountain_map := []

	# Prepare 2D arrays (width x height) initialized to 0.0
	for x in width:
		noise_map.append([])
		swamp_map.append([])
		snow_map.append([])
		mountain_map.append([])
		for y in height:
			noise_map[x].append(0.0)
			swamp_map[x].append(0.0)
			snow_map[x].append(0.0)
			mountain_map[x].append(0.0)
	

	var rand_seed := randi() % 100000

	# Experment with different noise values

	# Base terrain (fields, mountains, forests)
	var base_noise := FastNoiseLite.new()
	var noise_max := 0.0

	base_noise.seed = rand_seed
	base_noise.frequency = 0.008
	base_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	base_noise.fractal_octaves = 4
	base_noise.fractal_lacunarity = 2.25
	
	# Swamps
	var swamp_noise := FastNoiseLite.new()
	var swamp_noise_max := 0.0

	swamp_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	swamp_noise.seed = rand_seed
	swamp_noise.frequency = 0.04
	swamp_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	swamp_noise.fractal_lacunarity = 2

	# Snow
	var snow_noise := FastNoiseLite.new()
	var snow_noise_max := 0.0

	snow_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	snow_noise.seed = rand_seed
	snow_noise.frequency = 0.015
	snow_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	snow_noise.fractal_lacunarity = 2
	

	# Generate noise values
	for x in width:
		for y in height:
			#base
			noise_map[x][y] = abs(base_noise.get_noise_2d(x, y))
			noise_max = max(noise_max, noise_map[x][y])
			#swamp
			swamp_map[x][y] = abs(base_noise.get_noise_2d(x, y))
			swamp_noise_max = max(swamp_noise_max, swamp_map[x][y])
			#snow
			snow_map[x][y] = abs(base_noise.get_noise_2d(x, y))
			snow_noise_max = max(snow_noise_max, snow_map[x][y])
	
	var terrain_ranges := [
		{ "min": 0, "max": noise_max / 10.0 * 4, "type": hex.TerrainType.FIELDS },
		{ "min": noise_max / 10.0 * 4, "max": noise_max / 10.0 * 5, "type": hex.TerrainType.MOUNTAIN },
		{ "min": noise_max / 10.0 * 5, "max": noise_max + 0.05, "type": hex.TerrainType.FOREST }
	]

	# The upper 30% of the swamp noise will be swamp tiles
	# var swamp_ranges := [
	# 	{ "min": swamp_noise_max / 10.0 * 7, "max": swamp_noise_max + 0.05, "type": hex.TerrainType.SWAMP }
	# ]

	# var snow_ranges := [
	# 	{ "min": snow_noise_max / 10.0 * 7, "max": snow_noise_max + 0.05, "type": hex.TerrainType.SNOW }
	# ]
	
	var x_center = width / 2
	var y_center = height / 2

	for x in width:
		for y in height:
			var h := Hex.new(Vector2i(x, y))
			var noise_value: float = noise_map[x][y]
			
			for r in terrain_ranges:
				if noise_value >= r.min and noise_value < r.max:
					h.terrain_type = r.type
					break

			map_data[Vector2i(x,y)] = h

			# if swamp_noise[x][y] >= swamp_ranges[0].min and swamp_noise[x][y] < swamp_ranges[0].max:
			# 	h.terrain_type = hex.TerrainType.SWAMP
			# elif snow_noise[x][y] >= snow_ranges[0].min and snow_noise[x][y] < snow_ranges[0].max:
			# 	h.terrain_type = hex.TerrainType.SNOW
			
			# Outer Water tiles generation
			var border_thickness := 1
			if x < border_thickness or x >= width - border_thickness or y < border_thickness or y >= height - border_thickness:
				h.terrain_type = hex.TerrainType.WATER
			
			
			base_layer.set_cell(Vector2i(x, y), 0, terrain_textures[h.terrain_type])
			fog_overlay_layer.set_cell(Vector2i(x, y), 0, Vector2i(0,0))
			generate_minerals(h, Vector2i(x, y))
		
			if x == x_center and y == y_center:
				explore_tile(h)
			elif  h.terrain_type != hex.TerrainType.WATER:
				var containsEvent = randi_range(0, 4)
				if containsEvent == 1:
					h.special_state = hex.SpecialTileState.CURSED
					apply_special_tile_state(h, Vector2i(x, y))
				elif containsEvent == 2:
					h.special_state = hex.SpecialTileState.ENCAMPMENT
					apply_special_tile_state(h, Vector2i(x, y))

func generate_minerals(h: Hex, coords: Vector2i) -> void:
	# generate 2 resources on each tile except water
	if h.terrain_type != hex.TerrainType.WATER:
		minerals.shuffle()  # Randomize the order of the array
		var tile_minerals: Array[Mineral] = minerals.slice(0, 2)

		for i in tile_minerals.size():
			var mineral = tile_minerals[i]
			var mineral_ui: MineralUI = MINERAL_UI.instantiate() as MineralUI
			mineral_ui.map = self
			# Where on the map the mineral is located
			mineral_ui.center_coordinates = coords
			mineral_ui.tile = h
			h.minerals.append(mineral_ui)

			# Base position on the tile
			var base_pos = base_layer.map_to_local(coords)
			var offset = Vector2((i - (tile_minerals.size() - 1) / 2.0) * 72, -32)
			# Spread out horizontally and slightly above center
			mineral_ui.position = base_pos + offset  

			mineral_ui.set_mineral(mineral)
			# mineral.mineral_data = tile_mineral
			add_child(mineral_ui)
			mineral_ui.hide()
		
# Needs a special tile state scene
func apply_special_tile_state(h: Hex, coords: Vector2i) -> void:
	if h.special_state == hex.SpecialTileState.CURSED:
		var curse: CurseEvent = curse_scene.instantiate() as CurseEvent
		curse.map = self
		curse.tile = h
		curse.center_coordinates = coords
		h.curse = curse

		curse.position = base_layer.map_to_local(coords)
		# TODO get the curse data from the curse event
		# curse.curse_data = 
		add_child(curse)
		
	elif h.special_state == hex.SpecialTileState.ENCAMPMENT:
		pass
	
# Used for setting camera boundaries
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)

func update_explore_buttons() -> void:
	# Remove all existing explore buttons
	for child in get_children():
		if child is Button and child.has_method("_on_pressed"):
			child.queue_free()
	
	# Add explore buttons to tiles surrounding explored tiles
	for explored_tile in GameManager.explored_tiles:
		var surrounding_tiles = base_layer.get_surrounding_cells(explored_tile.coordinates)
		print(surrounding_tiles)
		for coords in surrounding_tiles:
			print(map_data.has(coords))
			if map_data.has(coords):
				print(coords)
				var h = map_data[coords]
				if not h.explored and h.terrain_type != h.TerrainType.WATER:
					print("Adding explore button to tile: ", coords)
					var explore_button = EXPLORE_BUTTON.instantiate()
					explore_button.hex = h
					explore_button.position = base_layer.map_to_local(coords)
					add_child(explore_button)

func explore_tile(h: Hex) -> void:
	fog_overlay_layer.set_cell(h._coordinates, -1)
	h.explored = true

	if h.curse != null:
		h.curse.curse_button.disabled = false
	h.on_explore()
	for i in h.minerals.size():
		h.minerals[i].show()

	GameManager.update_explored_tiles_list(h)
	update_explore_buttons()  # Update explore buttons after exploring a tile

func on_turn_ended():
	var delay_interval := 0.5

	for tile in GameManager.explored_tiles:
		# Create and start scale animation for individual tile
		var tile_pos = base_layer.map_to_local(tile._coordinates)
		
		# Create a temporary sprite for the animation
		var sprite = Sprite2D.new()
		var atlas_source = base_layer.tile_set.get_source(0) as TileSetAtlasSource
		var coords = terrain_textures[tile.terrain_type]
		var tile_id = atlas_source.get_tile_at_coords(coords)
		sprite.texture = atlas_source.texture
		sprite.region_enabled = true
		sprite.region_rect = atlas_source.get_tile_texture_region(tile_id)
		sprite.position = tile_pos
		sprite.centered = true
		base_layer.add_sibling(sprite, true)  # Add as sibling before base_layer
		
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_callback(sprite.queue_free)
		
		var floating_text = preload("res://scenes/animations/floating_text.tscn").instantiate()
		floating_text.position = tile_pos
		var gold_amount: int = tile.generate_gold()
		floating_text.set_text("+%s gold" % gold_amount, true)
		get_tree().current_scene.add_child(floating_text)

		await get_tree().create_timer(delay_interval).timeout

		for mineral_ui in tile.minerals:
			# Create another sprite for mineral animation
			var mineral_sprite = Sprite2D.new()
			mineral_sprite.texture = atlas_source.texture
			mineral_sprite.region_enabled = true
			mineral_sprite.region_rect = atlas_source.get_tile_texture_region(tile_id)
			mineral_sprite.position = tile_pos
			mineral_sprite.centered = true
			base_layer.add_sibling(mineral_sprite, true)  # Add as sibling before base_layer
			
			var mineral_tween = create_tween()
			mineral_tween.tween_property(mineral_sprite, "scale", Vector2(1.05, 1.05), 0.1)
			mineral_tween.tween_property(mineral_sprite, "scale", Vector2(1.0, 1.0), 0.1)
			mineral_tween.tween_callback(mineral_sprite.queue_free)
			
			var floating_text_mineral = preload("res://scenes/animations/floating_text.tscn").instantiate()
			floating_text_mineral.position = tile_pos
			var mineral_amount = tile.generate_mineral(mineral_ui)
			floating_text_mineral.set_text(("+%s %s") % [mineral_amount, mineral_ui.mineral.name], false)
			get_tree().current_scene.add_child(floating_text_mineral)

			await get_tree().create_timer(delay_interval).timeout
