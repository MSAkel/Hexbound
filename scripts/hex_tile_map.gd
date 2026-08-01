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
# Ring distance from center for each map tile (0 = center, hex_size = outer ring)
var _ring_distances: Dictionary = {}

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

# @onready var terrain_tile_ui: TerrainTileUI = $"../MainUI/TerrainTileUI"

# Special events UI
var CURSE_UI: PackedScene = preload("res://scenes/events/curse/curse_ui.tscn")
const RUINS_UI: PackedScene = preload("res://scenes/events/ruins/ruins_ui.tscn")


var selected_cell: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)
# Dictionary<Vector2i, Hex>
var map_data: Dictionary = {}
# Extra rune activations queued by support runes; resolved before tile flow continues.
var _pending_trigger_queue: Array[Dictionary] = []

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
		
	# Handle mouse motion for hover highlighting (only when no card is selected for placement)
	if not card_placement_handler.is_card_selected and event is InputEventMouseMotion:
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
				# terrain_tile_ui.set_hex(h)
				
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


# Returns map-adjacent hex tiles that exist on this map (0–6 neighbors).
func get_adjacent_hexes(coords: Vector2i) -> Array[Hex]:
	var neighbors: Array[Hex] = []
	for direction in _HEX_NEIGHBORS:
		var neighbor_coords: Vector2i = base_layer.get_neighbor_cell(coords, direction)
		if map_data.has(neighbor_coords):
			neighbors.append(map_data[neighbor_coords])
	return neighbors


# Outer ring tiles have at least one hex neighbor direction that leaves the map.
func is_edge_tile(coords: Vector2i) -> bool:
	for direction in _HEX_NEIGHBORS:
		var neighbor_coords: Vector2i = base_layer.get_neighbor_cell(coords, direction)
		if not map_data.has(neighbor_coords):
			return true
	return false


# Every rune currently placed on the map (order follows map generation).
func get_all_placed_runes() -> Array[Rune]:
	var runes: Array[Rune] = []
	for hex: Hex in map_data.values():
		if hex.active_rune != null:
			runes.append(hex.active_rune)
	return runes


# Hex tiles that currently hold a rune. Useful when effects need coordinates too
func get_all_hexes_with_runes() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in map_data.values():
		if hex.active_rune != null:
			hexes.append(hex)
	return hexes


# Adjacent map tiles with no rune placed on them.
func count_unoccupied_adjacent_hexes(coords: Vector2i) -> int:
	var count := 0
	for hex: Hex in get_adjacent_hexes(coords):
		if hex.active_rune == null:
			count += 1
	return count


# Adjacent map tiles occupied by a rune. Pass rune_type to filter by GENERATION or EFFECT.
func count_occupied_adjacent_hexes(coords: Vector2i, rune_type: Variant = null) -> int:
	var count := 0
	for hex: Hex in get_adjacent_hexes(coords):
		if hex.active_rune == null:
			continue
		if rune_type != null and hex.active_rune.type != rune_type:
			continue
		count += 1
	return count


func _place_hex_tile(offset: Vector2i) -> void:
	var h := Hex.new(offset)
	h.setup(self)
	map_data[offset] = h
	base_layer.set_cell(offset, 0, BASE_TILE_ATLAS_COORDS)


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

	_compute_ring_distances()


# Breadth-first ring index from the map center; reused by trigger-order sorting.
func _compute_ring_distances() -> void:
	_ring_distances.clear()
	var queue: Array[Vector2i] = [_hex_center]
	_ring_distances[_hex_center] = 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var distance: int = _ring_distances[current]
		for direction in _HEX_NEIGHBORS:
			var neighbor: Vector2i = base_layer.get_neighbor_cell(current, direction)
			if not map_data.has(neighbor) or _ring_distances.has(neighbor):
				continue
			_ring_distances[neighbor] = distance + 1
			queue.append(neighbor)


func _get_tiles_in_ring(ring: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for coords: Vector2i in map_data.keys():
		if _ring_distances.get(coords, -1) == ring:
			tiles.append(coords)
	return tiles


# Screen-space top-left tile on a ring; outer-to-inner order starts here each ring.
func _find_top_left_tile(cells: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = cells[0]
	for cell: Vector2i in cells:
		var pos: Vector2 = base_layer.map_to_local(cell)
		var best_pos: Vector2 = base_layer.map_to_local(best)
		if pos.y < best_pos.y or (is_equal_approx(pos.y, best_pos.y) and pos.x < best_pos.x):
			best = cell
	return best


# Screen-space tile closest to north-east; center spiral starts here on each ring.
func _find_ne_start_tile(cells: Array[Vector2i]) -> Vector2i:
	var center_pos: Vector2 = base_layer.map_to_local(_hex_center)
	const NE_ANGLE := -PI / 3.0
	var best: Vector2i = cells[0]
	var best_diff: float = INF
	for cell: Vector2i in cells:
		var pos: Vector2 = base_layer.map_to_local(cell)
		var angle: float = atan2(pos.y - center_pos.y, pos.x - center_pos.x)
		var diff: float = absf(fmod(angle - NE_ANGLE + PI, TAU) - PI)
		if diff < best_diff:
			best_diff = diff
			best = cell
	return best


# Sort ring tiles clockwise beginning at start_tile (angles measured from map center).
func _sort_ring_clockwise(cells: Array[Vector2i], start_tile: Vector2i) -> Array[Vector2i]:
	var sorted_cells: Array[Vector2i] = cells.duplicate()
	var center_pos: Vector2 = base_layer.map_to_local(_hex_center)
	var start_pos: Vector2 = base_layer.map_to_local(start_tile)
	var start_angle: float = atan2(start_pos.y - center_pos.y, start_pos.x - center_pos.x)

	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = base_layer.map_to_local(a)
		var pos_b: Vector2 = base_layer.map_to_local(b)
		var angle_a: float = atan2(pos_a.y - center_pos.y, pos_a.x - center_pos.x)
		var angle_b: float = atan2(pos_b.y - center_pos.y, pos_b.x - center_pos.x)
		var order_a: float = fmod(angle_a - start_angle + TAU, TAU)
		var order_b: float = fmod(angle_b - start_angle + TAU, TAU)
		return order_a < order_b
	)
	return sorted_cells


func _get_order_top_left_to_bottom_right() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	coords.assign(map_data.keys())
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pos_a: Vector2 = base_layer.map_to_local(a)
		var pos_b: Vector2 = base_layer.map_to_local(b)
		if not is_equal_approx(pos_a.y, pos_b.y):
			return pos_a.y < pos_b.y
		return pos_a.x < pos_b.x
	)
	return coords


func _get_order_outer_to_inner() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for ring in range(hex_size, -1, -1):
		var ring_tiles: Array[Vector2i] = _get_tiles_in_ring(ring)
		if ring == 0:
			coords.append(_hex_center)
			continue
		var start_tile: Vector2i = _find_top_left_tile(ring_tiles)
		coords.append_array(_sort_ring_clockwise(ring_tiles, start_tile))
	return coords


func _get_order_clockwise_spiral() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for ring in range(hex_size + 1):
		var ring_tiles: Array[Vector2i] = _get_tiles_in_ring(ring)
		if ring == 0:
			coords.append(_hex_center)
			continue
		var start_tile: Vector2i = _find_ne_start_tile(ring_tiles)
		coords.append_array(_sort_ring_clockwise(ring_tiles, start_tile))
	return coords


func get_coords_in_trigger_order() -> Array[Vector2i]:
	match GameManager.trigger_order:
		TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT:
			return _get_order_top_left_to_bottom_right()
		TriggerOrderType.Type.OUTER_RING_TO_INNER:
			return _get_order_outer_to_inner()
		TriggerOrderType.Type.CLOCKWISE_SPIRAL:
			return _get_order_clockwise_spiral()
		_:
			return _get_order_top_left_to_bottom_right()


func get_hexes_in_trigger_order() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for coords: Vector2i in get_coords_in_trigger_order():
		hexes.append(map_data[coords])
	return hexes


func _build_runes_in_activation_order() -> Array[Rune]:
	var runes_in_order: Array[Rune] = []
	for hex: Hex in get_hexes_in_trigger_order():
		if hex.active_rune != null:
			runes_in_order.append(hex.active_rune)
	return runes_in_order


func _get_hex_trigger_order_index(current_tile: Hex) -> int:
	var hexes := get_hexes_in_trigger_order()
	for i in range(hexes.size()):
		if hexes[i] == current_tile:
			return i
	return -1


# Rune on the very next hex in trigger order (null when that hex is empty).
func get_immediate_following_rune(current_tile: Hex) -> Rune:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1 or current_index + 1 >= hexes.size():
		return null
	return hexes[current_index + 1].active_rune


# True when the next hex in trigger order has a rune that is ready to be consumed.
func can_consume_immediate_following_rune(current_tile: Hex) -> bool:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1 or current_index + 1 >= hexes.size():
		return false
	
	var following_rune := hexes[current_index + 1].active_rune
	if following_rune == null:
		return false
	
	# Every rune on earlier hexes must have already activated this turn.
	for i in range(current_index):
		var prior_rune := hexes[i].active_rune
		if prior_rune != null and not GameManager.has_rune_activated_this_turn(prior_rune):
			return false
	
	return not GameManager.has_rune_activated_this_turn(following_rune)


# Runes that activate before/after current_tile in turn order (empty hexes are skipped).
# Pass filter_type (e.g. Rune.RuneType.GENERATION) to skip non-matching runes while filling count.
func get_runes_in_activation_order(
	current_tile: Hex,
	count: int = 1,
	before: bool = false,
	filter_type: Variant = null
) -> Array[Rune]:
	var runes_in_order := _build_runes_in_activation_order()
	var current_index := -1
	for i in range(runes_in_order.size()):
		if runes_in_order[i] == current_tile.active_rune:
			current_index = i
			break

	if current_index == -1:
		return []

	var result: Array[Rune] = []
	if before:
		# Closest preceding rune first (e.g. count=2 → [prev, prev-prev]).
		for i in range(current_index - 1, -1, -1):
			var rune := runes_in_order[i]
			if filter_type != null and rune.type != filter_type:
				continue
			result.append(rune)
			if result.size() >= count:
				break
	else:
		# Closest following rune first (default: one rune after the current one).
		for i in range(current_index + 1, runes_in_order.size()):
			var rune := runes_in_order[i]
			if filter_type != null and rune.type != filter_type:
				continue
			result.append(rune)
			if result.size() >= count:
				break
	return result

func get_hex_for_rune(rune: Rune) -> Hex:
	for hex: Hex in map_data.values():
		if hex.active_rune == rune:
			return hex
	return null


# Remove a placed rune from its tile and cancel any queued triggers targeting it.
func destroy_placed_rune(rune: Rune) -> void:
	var hex := get_hex_for_rune(rune)
	if hex == null:
		return
	
	hex.remove_rune()
	
	for i in range(_pending_trigger_queue.size() - 1, -1, -1):
		if _pending_trigger_queue[i]["rune"] == rune:
			_pending_trigger_queue.remove_at(i)


func queue_rune_triggers(runes: Array[Rune], score_multipliers: Array[float] = []) -> void:
	for i in range(runes.size()):
		var multiplier := 1.0
		if i < score_multipliers.size():
			multiplier = score_multipliers[i]
		_pending_trigger_queue.append({
			"rune": runes[i],
			"score_multiplier": multiplier,
		})


func create_floating_text(pos: Vector2, text: String, is_gold: bool) -> void:
	var floating_text = preload("res://scenes/animations/floating_text.tscn").instantiate()
	floating_text.position = pos
	floating_text.set_text(text, is_gold)
	get_tree().current_scene.add_child(floating_text)

# Used for setting camera boundaries and other coordinate conversions
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)

func on_turn_ended() -> void:
	var base_delay_interval := 0.5
	_pending_trigger_queue.clear()

	# Process rune effects in the active trigger order.
	for tile: Hex in get_hexes_in_trigger_order():
		if tile.active_rune == null:
			continue

		var delay_interval := base_delay_interval / GameManager.game_speed
		await _resolve_rune_activation(tile)
		await get_tree().create_timer(delay_interval).timeout

	GameManager.finish_turn_processing()


# Resolve one tile: primary activation, then any queued secondary triggers.
func _resolve_rune_activation(tile: Hex) -> void:
	await _activate_rune_on_tile(tile)

	while not _pending_trigger_queue.is_empty():
		var entry: Dictionary = _pending_trigger_queue.pop_front()
		var target_hex := get_hex_for_rune(entry["rune"])
		if target_hex == null or target_hex.active_rune == null:
			continue
		await _activate_rune_on_tile(
			target_hex,
			entry["score_multiplier"],
			true
		)


func _activate_rune_on_tile(
	tile: Hex,
	score_multiplier: float = 1.0,
	skip_cost: bool = false
) -> void:
	if tile.active_rune == null:
		return
	
	if tile.active_rune.is_active and (skip_cost or tile.active_rune.can_activate()):
		tile.play_rune_activation_animation(skip_cost)
		await _wait_for_activation_animation()
	
	tile.apply_rune_activation(score_multiplier, skip_cost)


func _wait_for_activation_animation() -> void:
	var duration := RuneUI.ACTIVATION_POP_DURATION + RuneUI.ACTIVATION_SETTLE_DURATION
	await get_tree().create_timer(duration / GameManager.game_speed).timeout
