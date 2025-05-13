class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
#@onready var hex_border_layer: TileMapLayer = $HexBorderLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer

@export var width := 7
@export var height := 7

@export var resource_list: Array[ResourceData] = []
#@onready var base_layer: TileMapLayer = $BaseLayer

@onready var terrain_tile_ui: TerrainTileUI = $"../CanvasLayer/TerrainTileUi"

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
	generate_resources()

# Handles listening to tile clicks and selection
func _unhandled_input(event: InputEvent) -> void:
	# only detect input if it hasn't already been consumed
	if event is InputEventMouseButton:
		var map_coords: Vector2i = base_layer.local_to_map(to_local(get_global_mouse_position()))
		# Check if mouse click is within terrain boundaries
		if map_coords.x >= 0 && map_coords.x < width && map_coords.y >= 0 && map_coords.y < height:
			if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
				print(map_data[map_coords].get_tile_data())
				var h: Hex = map_data[map_coords]
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

func generate_resources() -> void:
	for x in width:
		for y in height:
			var h : Hex = map_data[Vector2i(x, y)]
			resource_list.shuffle()  # Randomize the order of the array
			var tile_resources: Array[ResourceData] = resource_list.slice(0, 2)
			h.resource_1 = tile_resources[0]
			h.resource_2 = tile_resources[1]

	#for x in width:
		#for y in height:
			#var h: Hex = map_data[Vector2i(x,y)]
			#
			#match h._terrain_type:
				#hex.TerrainType.FIELDS:
					#h.
		
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
	
	#var mountain_noise := FastNoiseLite.new()
	
	# Generate noise values
	for x in width:
		for y in height:
			# Moving water to edge of map, disabled for now and using the more straightforward approach
			# Calculate distance to center
			#var center := Vector2(width / 2, height / 2)
			#var distance := Vector2(x, y).distance_to(center)
			#var max_distance := center.length()  # max possible distance in the map
#
			## Create falloff value: closer to edge = closer to 1
			#var edge_falloff: float = clamp(distance / max_distance, 0.0, 1.0)
#
			## Sharpen the falloff with a curve
			#edge_falloff = pow(edge_falloff, 3)  # stronger near edges
#
			## Apply falloff to terrain noise (push edge values down toward water)
			#noise_map[x][y] *= (1.0 - edge_falloff)
						
			
			# Base terrain
			noise_map[x][y] = abs(base_noise.get_noise_2d(x, y))
			noise_max = max(noise_max, noise_map[x][y])
	
	#var terrain_ranges := [
		#{ "min": 0.0, "max": noise_max / 10.0 * 7.5, "type": hex.TerrainType.FIELDS },
		##{ "min": noise_max / 10.0 * 4.0, "max": noise_max / 10.0 * 4.5, "type": hex.TerrainType.FIELDS },
		#{ "min": noise_max / 10.0 * 1.5, "max": noise_max + 0.05, "type": hex.TerrainType.FOREST }
	#]
	var terrain_ranges := [
		#{ "min": 0.0, "max": noise_max / 10.0 * 0.2, "type": hex.TerrainType.WATER },
		{ "min": 0, "max": noise_max / 10.0 * 4.5, "type": hex.TerrainType.FIELDS },
		{ "min": noise_max / 10.0 * 2.0, "max": noise_max / 10.0 * 3, "type": hex.TerrainType.MOUNTAIN },
		{ "min": noise_max / 10.0 * 1.5, "max": noise_max + 0.05, "type": hex.TerrainType.FOREST }
	]
	
	for x in width:
		for y in height:			
			var _hex := Hex.new(Vector2i(x, y))
			var noise_value: float = noise_map[x][y]
			
			for r in terrain_ranges:
				if noise_value >= r.min and noise_value < r.max:
					_hex._terrain_type = r.type
					break

			map_data[Vector2i(x,y)] = _hex
			
			# Outer Water tiles generation
			var border_thickness := 1
			if x < border_thickness or x >= width - border_thickness or y < border_thickness or y >= height - border_thickness:
				_hex._terrain_type = hex.TerrainType.WATER
			
			base_layer.set_cell(Vector2i(x, y), 0, terrain_textures[_hex._terrain_type])
			
			
	
# Used for setting camera boundaries
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)
