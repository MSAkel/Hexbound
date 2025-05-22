class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var fog_overlay_layer: TileMapLayer = $FogOverlayLayer

# Map size
@export var width: int
@export var height: int

@export var minerals: Array[Mineral] = []
@onready var terrain_tile_ui: TerrainTileUI = $"../MainUI/TerrainTileUi"

const MINERAL_UI: PackedScene = preload("res://scenes/ui/minerals/mineral_ui.tscn")
const EXPLORE_BUTTON: PackedScene = preload("res://scenes/ui/explore_button.tscn")
# Special events UI
var CURSE_UI: PackedScene = preload("res://scenes/events/curse/curse_ui.tscn")
const RUINS_UI: PackedScene = preload("res://scenes/events/ruins/ruins_ui.tscn")

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
	Events.turn_ended.connect(on_turn_ended)
	GameManager.tile_explored.connect(explore_tile)
	# Add initial explore button after terrain generation is complete
	update_explore_buttons()

# Handles listening to tile clicks and selection
func _unhandled_input(event: InputEvent) -> void:
	# Skip input handling if turn is being processed
	if GameManager.is_processing_turn:
		return
		
	# only detect input if it hasn't already been consumed
	if event is InputEventMouseButton:
		var map_coords: Vector2i = base_layer.local_to_map(to_local(get_global_mouse_position()))
		# Check if mouse click is within terrain boundaries
		if map_coords.x >= 0 && map_coords.x < width && map_coords.y >= 0 && map_coords.y < height:
			if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
				var h: Hex = map_data[map_coords]
				if h.explored and h.terrain_type != hex.TerrainType.WATER:
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
	
	var x_center = width / 2
	var y_center = height / 2

	for x in width:
		for y in height:
			var h := Hex.new(Vector2i(x, y))
			h.setup(self, MINERAL_UI)
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
			h.generate_minerals(minerals)
		
			if x == x_center and y == y_center:
				explore_tile(h)
			elif h.terrain_type != hex.TerrainType.WATER:
				var containsEvent = randi_range(0, 6)
				if containsEvent == 1:
					h.special_state = hex.SpecialTileState.CURSED
					h.apply_special_state()
				elif containsEvent == 2:
					h.special_state = hex.SpecialTileState.RUINS
					h.apply_special_state()

func update_explore_buttons() -> void:
	# Remove all existing explore buttons
	for child in get_children():
		if child is Button and child.has_method("_on_pressed"):
			child.queue_free()
	
	# Add explore buttons to tiles surrounding explored tiles
	for explored_tile in GameManager.explored_tiles:
		var surrounding_tiles = base_layer.get_surrounding_cells(explored_tile.coordinates)
		for coords in surrounding_tiles:
			if map_data.has(coords):
				var h = map_data[coords]
				if not h.explored and h.terrain_type != h.TerrainType.WATER:
					var explore_button = EXPLORE_BUTTON.instantiate()
					explore_button.hex = h
					explore_button.position = base_layer.map_to_local(coords)
					add_child(explore_button)

func explore_tile(h: Hex) -> void:
	fog_overlay_layer.set_cell(h._coordinates, -1)
	h.explore()
	update_explore_buttons()

func create_floating_text(pos: Vector2, text: String, is_gold: bool) -> void:
	var floating_text = preload("res://scenes/animations/floating_text.tscn").instantiate()
	floating_text.position = pos
	floating_text.set_text(text, is_gold)
	get_tree().current_scene.add_child(floating_text)

# Used for setting camera boundaries and other coordinate conversions
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)

func on_turn_ended():
	var base_delay_interval := 0.5
	var vertical_offset := 0

	for tile in GameManager.explored_tiles:
		# Calculate delay interval for each tile to respect current game speed
		var delay_interval := base_delay_interval / GameManager.game_speed
		
		tile.create_resource_animation("gold", tile.generate_gold(), vertical_offset)
		vertical_offset += 20
		await get_tree().create_timer(delay_interval).timeout

		for mineral_ui in tile.minerals:
			var mineral_amount = tile.produce_mineral(mineral_ui)
			tile.create_resource_animation(mineral_ui.mineral.name, mineral_amount, vertical_offset)
			vertical_offset += 20
			await get_tree().create_timer(delay_interval).timeout
		
		vertical_offset = 0
	
	# Signal that turn processing is complete
	GameManager.finish_turn_processing()
