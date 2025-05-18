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
		var tile_minerals: Array[MineralData] = minerals.slice(0, 2)

		for i in tile_minerals.size():
			var tile_mineral = tile_minerals[i]
			var mineral: Mineral = mineral_scene.instantiate() as Mineral
			mineral.map = self
			# Where on the map the mineral is located
			mineral.center_coordinates = coords
			mineral.tile = h
			h.minerals.append(mineral)

			# Base position on the tile
			var base_pos = base_layer.map_to_local(coords)
			var offset = Vector2((i - (tile_minerals.size() - 1) / 2.0) * 72, -32)
			# Spread out horizontally and slightly above center
			mineral.position = base_pos + offset  

			mineral.mineral_data = tile_mineral
			add_child(mineral)
			mineral.hide()
		
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

func explore_tile(h: Hex) -> void:
	fog_overlay_layer.set_cell(h._coordinates, -1)
	h.explored = true

	if h.curse != null:
		h.curse.curse_button.disabled = false

	GameManager.explored_tiles.append(h)
	for i in h.minerals.size():
		h.minerals[i].show()

func on_turn_ended():
	print("hex_title")
