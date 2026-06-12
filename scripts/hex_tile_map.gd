class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var fog_overlay_layer: TileMapLayer = $FogOverlayLayer
@onready var card_drop_overlay_layer: TileMapLayer = $CardDropOverlayLayer

# Map size
@export var width: int
@export var height: int
# @export var minerals: Array[Mineral] = []
@onready var terrain_tile_ui: TerrainTileUI = $"../MainUI/TerrainTileUI"

# const MINERAL_UI: PackedScene = preload("res://scenes/ui/minerals/mineral_ui.tscn")
const EXPLORE_BUTTON: PackedScene = preload("res://scenes/ui/explore_button.tscn")
# Special events UI
var CURSE_UI: PackedScene = preload("res://scenes/events/curse/curse_ui.tscn")
const RUINS_UI: PackedScene = preload("res://scenes/events/ruins/ruins_ui.tscn")

#The starting Building
const HQ = preload("uid://ctxjopaym03xl")
#The starting Rune
# const ROUNDABOUT_RUNE = preload("res://resources/runes/roundabout_rune.tres")

# Shader for fog effect
const FOG_SHADER = preload("res://shaders/fog_overlay.gdshader")

var hex: Hex
var selected_cell: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)
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

# Card placement handler
var card_placement_handler: CardPlacementHandler

func _ready() -> void:
	generate_terrain()
	Events.turn_ended.connect(on_turn_ended)
	GameManager.tile_explored.connect(explore_tile)
	# Add initial explore button after terrain generation is complete
	update_explore_buttons()
	
	# Apply fog shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = FOG_SHADER
	fog_overlay_layer.material = shader_material
	
	# Create and setup card placement handler
	card_placement_handler = CardPlacementHandler.new()
	card_placement_handler.tile_map = self
	add_child(card_placement_handler)


#_unhandled_input only receives events that haven't been handled by other nodes
#_input receives all input events, regardless of whether they've been handled by other nodes
# Handles listening to tile clicks and selection
func _unhandled_input(event: InputEvent) -> void:
	# Skip input handling if turn is being processed
	if GameManager.is_processing_turn:
		return
		
	# Handle mouse motion for hover highlighting (only when not dragging cards)
	if not card_placement_handler.is_card_dragging and event is InputEventMouseMotion:
		var map_coords: Vector2i = base_layer.local_to_map(to_local(get_global_mouse_position()))
		# Check if mouse is within terrain boundaries
		if map_coords.x >= 0 && map_coords.x < width && map_coords.y >= 0 && map_coords.y < height:
			# Only update hover if we've moved to a different tile
			if map_coords != hovered_cell:
				# Clear previous hover (if it existed and wasn't selected)
				if hovered_cell != Vector2i(-1, -1) and hovered_cell != selected_cell:
					selection_overlay_layer.set_cell(hovered_cell, -1)
				
				hovered_cell = map_coords
				var h: Hex = map_data[map_coords]
				# Apply hover highlight only on explored tiles (not water, not selected)
				if h.explored and h.terrain_type != hex.TerrainType.WATER and map_coords != selected_cell:
					selection_overlay_layer.set_cell(map_coords, 0, Vector2i(0,0))
				# If hovering over selected tile, don't show hover (selection overlay is already showing)
				elif map_coords == selected_cell:
					hovered_cell = Vector2i(-1, -1)
		else:
			# Clear hover when mouse leaves the map (if not selected)
			if hovered_cell != Vector2i(-1, -1) and hovered_cell != selected_cell:
				selection_overlay_layer.set_cell(hovered_cell, -1)
				hovered_cell = Vector2i(-1, -1)
		
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
					
					# Clear hover if it's on the tile we're selecting
					if hovered_cell == map_coords:
						selection_overlay_layer.set_cell(hovered_cell, -1)
						hovered_cell = Vector2i(-1, -1)
						
					# Apply overlay tile on selecting a tile (use source 2 for selection)
					selection_overlay_layer.set_cell(map_coords, 2, Vector2i(0,0))
					selected_cell = map_coords
		else:
			# Deselect active cell on clicking outside the map
			selection_overlay_layer.set_cell(selected_cell, -1)
			selected_cell = Vector2i(-1, -1)
			
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
	
	@warning_ignore("integer_division")
	var x_center = width / 2
	@warning_ignore("integer_division")
	var y_center = height / 2
	
	# Get protected tiles (center + adjacent tiles) that should not be mountains
	var center_coords = Vector2i(x_center, y_center)
	var protected_tiles: Array[Vector2i] = [center_coords]
	var surrounding_center = base_layer.get_surrounding_cells(center_coords)
	protected_tiles.append_array(surrounding_center)

	for x in width:
		for y in height:
			var h := Hex.new(Vector2i(x, y))
			h.setup(self)  # Pass self as the map reference
			var noise_value: float = noise_map[x][y]
			
			for r in terrain_ranges:
				if noise_value >= r.min and noise_value < r.max:
					h.terrain_type = r.type
					break

			map_data[Vector2i(x,y)] = h
			
			# Outer Water tiles generation
			var border_thickness := 1
			var is_water_tile: bool = false
			if x < border_thickness or x >= width - border_thickness or y < border_thickness or y >= height - border_thickness:
				h.terrain_type = hex.TerrainType.WATER
				is_water_tile = true
			
			# Prevent mountains on starting tile and adjacent tiles (but not water tiles)
			var current_coords = Vector2i(x, y)
			if not is_water_tile and current_coords in protected_tiles and h.terrain_type == hex.TerrainType.MOUNTAIN:
				h.terrain_type = hex.TerrainType.FIELDS
			
			base_layer.set_cell(Vector2i(x, y), 0, terrain_textures[h.terrain_type])
			fog_overlay_layer.set_cell(Vector2i(x, y), 0, Vector2i(0,0))
			# h.generate_minerals(minerals)
		
			# Generate special events on tiles. Exclude the center tile and water tiles
			if h.terrain_type != hex.TerrainType.WATER and (x != x_center and y != y_center):
				var containsEvent = randi_range(0, 6)
				if containsEvent == 1:
					h.special_state = hex.SpecialTileState.CURSED
					h.apply_special_state()
				elif containsEvent == 2:
					h.special_state = hex.SpecialTileState.RUINS
					h.apply_special_state()

	on_game_started(x_center, y_center)

# Handle game start events
func on_game_started(x_center: int, y_center: int) -> void:
	# Explore center and surrounding tiles after all tiles are generated
	var center_hex = map_data[Vector2i(x_center, y_center)]
	explore_tile(center_hex)
	
	# Place HQ building instance on the center tile
	var hq_instance: Headquarters = HQ.instantiate()
	hq_instance.map = self
	hq_instance.tile = center_hex
	hq_instance.center_coordinates = center_hex.coordinates
	
	# Set size for the HQ instance
	hq_instance.custom_minimum_size = Vector2(100, 100)
	hq_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hq_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Add to grid instead of directly to map
	center_hex.items_grid.add_child(hq_instance)
	center_hex._reposition_items()
	
	# Place roundabout rune on the center tile
	# center_hex.place_rune(ROUNDABOUT_RUNE)

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
					# Center the button on the tile
					explore_button.position -= explore_button.size / 2
					add_child(explore_button)

func explore_tile(h: Hex) -> void:
	fog_overlay_layer.set_cell(h._coordinates, -1)
	h.explore()
	
	# Explore surrounding tiles on initial load and exploration
	var surrounding_tiles = base_layer.get_surrounding_cells(h.coordinates)
	for coords in surrounding_tiles:
		if map_data.has(coords):
			var surrounding_hex = map_data[coords]
			if not surrounding_hex.explored:
				fog_overlay_layer.set_cell(surrounding_hex._coordinates, -1)
				surrounding_hex.explore()
	
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
	# delay between each rune activation
	var base_delay_interval := 0.5

	# Process rune effects, one tile at a time
	for tile in GameManager.explored_tiles:
		if tile.active_rune != null:
			# Calculate delay interval for each tile to respect current game speed
			var delay_interval := base_delay_interval / GameManager.game_speed

			tile.trigger_rune_activation()
			await get_tree().create_timer(delay_interval).timeout
					
	# Signal that turn processing is complete
	GameManager.finish_turn_processing()
