class_name  HexTileMap
extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var card_drop_overlay_layer: TileMapLayer = $CardDropOverlayLayer

# Hexagon radius — tiles from center to each outer edge (hex_size=2 → 19 tiles)
@export_range(1, 20, 1) var hex_size: int = 2
# Extra pixels added to tile_size so adjacent hex visuals do not touch
@export_range(0, 64, 1) var hex_tile_gap: int = 16

# Offset coords of the hexagon center; set during map generation
var _hex_center: Vector2i = Vector2i.ZERO

# Dashed hex art size; tile_size = this + hex_tile_gap for spacing on the grid
const HEX_TEXTURE_SIZE := 256

# Atlas coords for the single dashed hex tile on BaseLayer (source 0)
const BASE_TILE_ATLAS_COORDS := Vector2i(0, 0)

# Six adjacent directions for Godot's flat-top hex tile layout
const _HEX_NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
]
# @export var minerals: Array[Mineral] = []
@onready var terrain_tile_ui: TerrainTileUI = $"../MainUI/TerrainTileUI"

# const MINERAL_UI: PackedScene = preload("res://scenes/ui/minerals/mineral_ui.tscn")
# Special events UI
var CURSE_UI: PackedScene = preload("res://scenes/events/curse/curse_ui.tscn")
const RUINS_UI: PackedScene = preload("res://scenes/events/ruins/ruins_ui.tscn")

#The starting Rune
# const ROUNDABOUT_RUNE = preload("res://resources/runes/roundabout_rune.tres")

var selected_cell: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)
# Dictionary<Vector2i, Hex>
var map_data: Dictionary = {}

# Card placement handler
var card_placement_handler: CardPlacementHandler

func _ready() -> void:
	_apply_tile_spacing()
	generate_terrain()
	Events.turn_ended.connect(on_turn_ended)
	
	# Create and setup card placement handler
	card_placement_handler = CardPlacementHandler.new()
	card_placement_handler.tile_map = self
	add_child(card_placement_handler)


# Widen the hex grid cells while keeping 256px textures, creating visible gaps
func _apply_tile_spacing() -> void:
	var spaced_tile_size := Vector2i(
		HEX_TEXTURE_SIZE + hex_tile_gap,
		HEX_TEXTURE_SIZE + hex_tile_gap
	)
	for layer: TileMapLayer in [base_layer, selection_overlay_layer, card_drop_overlay_layer]:
		layer.tile_set.tile_size = spaced_tile_size


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
		# Check if mouse is within the hexagon-shaped map
		if is_in_map(map_coords):
			# Only update hover if we've moved to a different tile
			if map_coords != hovered_cell:
				# Clear previous hover (if it existed and wasn't selected)
				if hovered_cell != Vector2i(-1, -1) and hovered_cell != selected_cell:
					selection_overlay_layer.set_cell(hovered_cell, -1)
				
				hovered_cell = map_coords
				# Apply hover highlight on non-selected tiles
				if map_coords != selected_cell:
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
		# Check if mouse click is within the hexagon-shaped map
		if is_in_map(map_coords):
			if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
				var h: Hex = map_data[map_coords]
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
			
func is_in_map(coords: Vector2i) -> bool:
	return map_data.has(coords)


func _place_hex_tile(offset: Vector2i) -> void:
	var h := Hex.new(offset)
	h.setup(self)
	map_data[offset] = h
	base_layer.set_cell(offset, 0, BASE_TILE_ATLAS_COORDS)

	# Roll optional special events on each tile
	# var contains_event := randi_range(0, 6)
	# if contains_event == 1:
	# 	h.special_state = hex.SpecialTileState.CURSED
	# 	h.apply_special_state()
	# elif contains_event == 2:
	# 	h.special_state = hex.SpecialTileState.RUINS
	# 	h.apply_special_state()

func generate_terrain() -> void:
	map_data.clear()
	base_layer.clear()
	selection_overlay_layer.clear()
	card_drop_overlay_layer.clear()

	# Center tile with room to grow hex_size rings in every direction
	_hex_center = Vector2i(hex_size, hex_size)
	_place_hex_tile(_hex_center)

	# Expand ring-by-ring using Godot's hex neighbor graph for a symmetric hexagon
	var frontier: Array[Vector2i] = [_hex_center]
	for _ring in hex_size:
		var next_frontier: Array[Vector2i] = []
		for cell in frontier:
			for direction in _HEX_NEIGHBORS:
				var neighbor: Vector2i = base_layer.get_neighbor_cell(cell, direction)
				if map_data.has(neighbor):
					continue
				_place_hex_tile(neighbor)
				next_frontier.append(neighbor)
		frontier = next_frontier

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
	for tile: Hex in map_data.values():
		if tile.active_rune != null:
			# Calculate delay interval for each tile to respect current game speed
			var delay_interval := base_delay_interval / GameManager.game_speed

			tile.trigger_rune_activation()
			await get_tree().create_timer(delay_interval).timeout
					
	# Signal that turn processing is complete
	GameManager.finish_turn_processing()
