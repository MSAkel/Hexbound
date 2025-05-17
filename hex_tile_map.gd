class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
#@onready var hex_border_layer: TileMapLayer = $HexBorderLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var fog_overlay_layer: TileMapLayer = $FogOverlayLayer

# Map size
@export var width: int
@export var height: int

@export var cursed_tiles_count := 3

@export var minerals: Array[MineralData] = []
@onready var terrain_tile_ui: TerrainTileUI = $"../MainUI/TerrainTileUi"

var mineral_scene: PackedScene = preload("res://scenes/ui/mineral.tscn")
var hex: Hex
var selected_cell: Vector2i = Vector2i(-1, -1)
var map_data: Dictionary = {}  # Dictionary<Vector2i, Hex>
var terrain_textures: Dictionary = {
	hex.TerrainType.FIELDS: Vector2i(0,0),
	hex.TerrainType.FOREST: Vector2i(1,0),
	hex.TerrainType.MOUNTAIN: Vector2i(2,0),
	hex.TerrainType.SNOW: Vector2i(3,0),
	hex.TerrainType.WATER: Vector2i(4,0),
	hex.TerrainType.SWAMP: Vector2i(5,0),
	hex.TerrainType.CURSED: Vector2i(6,0),
}

func _ready() -> void:
	generate_terrain()
	# generate_minerals()
	GameManager.turn_ended.connect(on_turn_ended)
	GameManager.tile_explored.connect(explore_tile)

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
					terrain_tile_ui._set_hex(h)
					
					# Remove the current overlay texture on selecting a different tile
					if map_coords != selected_cell:
						selection_overlay_layer.set_cell(selected_cell, -1)
						
					# Apply overlay tile on selecting a tile
					selection_overlay_layer.set_cell(map_coords, 0, Vector2i(0,0))
					selected_cell = map_coords
		else:
			# Deselect active cell on clicking outside the map
			selection_overlay_layer.set_cell(selected_cell, -1)

# func generate_minerals_2() -> void:
# 	for x in width:
# 		for y in height:
# 			var h : Hex = map_data[Vector2i(x, y)]
			
# 			# generate 2 resources on each tile except water
# 			if h.terrain_type != hex.TerrainType.WATER:
# 				minerals.shuffle()  # Randomize the order of the array
# 				var tile_minerals: Array[MineralData] = minerals.slice(0, 2)
# 				h.mineral_1 = tile_minerals[0]
# 				h.mineral_2 = tile_minerals[1]
				
# 				# Geneate mineral icons on the tiles
# 				var base_pos := base_layer.map_to_local(Vector2i(x, y))
# 				var set_icon_size := Vector2(64, 64)

			
# 				var mineral_icon_1 := Sprite2D.new() 
# 				mineral_icon_1.texture = tile_minerals[0].icon
# 				mineral_icon_1.position = base_pos + Vector2(-30, -32)
				
# 				var texture_size_1 := mineral_icon_1.texture.get_size()
# 				mineral_icon_1.scale = set_icon_size / texture_size_1
# 				add_child(mineral_icon_1)
				
# 				var mineral_icon_1_icon_2 := Sprite2D.new() 
# 				mineral_icon_1_icon_2.texture = tile_minerals[1].icon
# 				mineral_icon_1_icon_2.position = base_pos + Vector2(30, -32)
				
# 				var texture_size_2 := mineral_icon_1_icon_2.texture.get_size()
# 				mineral_icon_1_icon_2.scale = set_icon_size / texture_size_2
# 				add_child(mineral_icon_1_icon_2)
				
# 				if h.terrain_type == hex.TerrainType.CURSED:
# 					#var base_pos := base_layer.map_to_local(Vector2i(x, y))
# 					var curse_icon := Sprite2D.new() 
# 					curse_icon.texture = preload("res://assets/icons/events/curse.png")
# 					print(curse_icon.texture)
# 					curse_icon.position = base_pos + Vector2(0, 24)
# 					add_child(curse_icon)
	
func generate_terrain() -> void:
	# Initialize noise maps for terrain features
	var noise_map := []
	var forest_map := []
	var desert_map := []
	var mountain_map := []

	# Prepare 2D arrays (width x height) initialized to 0.0
	for x in width:
		noise_map.append([])
		forest_map.append([])
		desert_map.append([])
		mountain_map.append([])
		for y in height:
			noise_map[x].append(0.0)
			forest_map[x].append(0.0)
			desert_map[x].append(0.0)
			mountain_map[x].append(0.0)
	
	# Generate a random seed
	var rand_seed := randi() % 100000
	
	var base_noise := FastNoiseLite.new()
	base_noise.seed = rand_seed
	base_noise.frequency = 0.008
	base_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	base_noise.fractal_octaves = 4
	base_noise.fractal_lacunarity = 2.25
	
	var noise_max := 0.0
	
	# Generate noise values
	for x in width:
		for y in height:
			# Base terrain
			noise_map[x][y] = abs(base_noise.get_noise_2d(x, y))
			noise_max = max(noise_max, noise_map[x][y])
	
	var terrain_ranges := [
		{ "min": 0, "max": noise_max / 10.0 * 4, "type": hex.TerrainType.FIELDS },
		{ "min": noise_max / 10.0 * 4, "max": noise_max / 10.0 * 5, "type": hex.TerrainType.MOUNTAIN },
		{ "min": noise_max / 10.0 * 5, "max": noise_max + 0.05, "type": hex.TerrainType.FOREST }
	]
	
	var cursed_tiles = generate_cursed_tiles_coords()
	
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
			
			# Outer Water tiles generation
			var border_thickness := 1
			if x < border_thickness or x >= width - border_thickness or y < border_thickness or y >= height - border_thickness:
				h.terrain_type = hex.TerrainType.WATER
			
			# Final override for special tiles
			var coord := Vector2i(x, y)
			if cursed_tiles.has(coord):
				h.terrain_type = cursed_tiles[coord]
			
			base_layer.set_cell(Vector2i(x, y), 0, terrain_textures[h.terrain_type])
			fog_overlay_layer.set_cell(Vector2i(x, y), 0, Vector2i(0,0))
			generate_minerals(h, Vector2i(x, y))

			if x == x_center and y == y_center:
				explore_tile(h)

			

	
func generate_minerals(h: Hex, coords: Vector2i) -> void:
	# generate 2 resources on each tile except water
	if h.terrain_type != hex.TerrainType.WATER:
		minerals.shuffle()  # Randomize the order of the array
		var tile_minerals: Array[MineralData] = minerals.slice(0, 2)

		for i in tile_minerals.size():
			var tile_mineral = tile_minerals[i]
			var mineral: Mineral = mineral_scene.instantiate() as Mineral
			mineral.map = self
			h.minerals.append(mineral)
			mineral.tile = h

			# Where on the map the mineral is located
			mineral.center_coordinates = coords

			# Base position on the tile
			var base_pos = base_layer.map_to_local(coords)
			var offset = Vector2((i - (tile_minerals.size() - 1) / 2.0) * 72, -32)
			# Spread out horizontally and slightly above center
			mineral.position = base_pos + offset  

			mineral.mineral_data = tile_mineral
			add_child(mineral)
			mineral.hide()
		

		if h.terrain_type == hex.TerrainType.CURSED:
			var curse_icon := Sprite2D.new() 
			curse_icon.texture = preload("res://assets/icons/events/curse.png")
			curse_icon.position =  Vector2i(0, 24)
			h.add_child(curse_icon)

func generate_cursed_tiles_coords():
	var cursed_tiles_coords := {}
	while cursed_tiles_coords.size() < cursed_tiles_count:
		# the 1 is the value of border_thickness
		var rx = randi() % (width - 1 * 2) + 1
		var ry = randi() % (height - 1 * 2) + 1
		var pos = Vector2i(rx, ry)
		cursed_tiles_coords[pos] = hex.TerrainType.CURSED
	
	return cursed_tiles_coords

# Used for setting camera boundaries
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)

func explore_tile(h: Hex) -> void:
	fog_overlay_layer.set_cell(h._coordinates, -1)
	h.explored = true
	GameManager.explored_tiles.append(h)
	for i in h.minerals.size():
		h.minerals[i].show()

func on_turn_ended():
	print("hex_title")
