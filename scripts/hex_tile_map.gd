class_name HexTileMap
extends Node2D

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var tile_panel: TilePanel = $"../MainUI/TerrainTileUI"
@onready var base_layer: TileMapLayer = $BaseLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var card_drop_overlay_layer: TileMapLayer = $CardDropOverlayLayer
@onready var disabled_tile_overlay_layer: TileMapLayer = $DisabledTileOverlayLayer
@onready var fading_sector_overlay_layer: TileMapLayer = $FadingSectorOverlayLayer

# Selection overlay uses source 0 for hover and source 2 for the locked selection.
const HOVER_OVERLAY_SOURCE_ID := 0
const SELECTED_OVERLAY_SOURCE_ID := 2
const OVERLAY_TILE_ATLAS_COORDS := Vector2i(0, 0)
# Disabled and fading-sector layers each expose a single tile on source 0.
const OVERLAY_TILE_SOURCE_ID := 0

# Hexagon radius — tiles from center to each outer edge (hex_size=2 → 19 tiles)
@export_range(1, 20, 1) var hex_size: int = 2
# Extra pixels added to tile_size so adjacent hex visuals do not touch
@export_range(0, 64, 1) var hex_tile_gap: int = 16

# Dashed hex art size; tile_size = this + hex_tile_gap for spacing on the grid
const HEX_TEXTURE_SIZE := 256

# Atlas coords for the single dashed hex tile on BaseLayer (source 0)
const BASE_TILE_ATLAS_COORDS := Vector2i(0, 0)

var selected_cell: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)
# Dictionary<Vector2i, Hex>
var map_data: Dictionary = {}
# Extra rune activations queued by support runes; resolved before tile flow continues.
var _pending_trigger_queue: Array[Dictionary] = []
# Ring distances, trigger order, and segment grouping.
var _layout: HexMapLayout

# Card placement handler
var card_placement_handler: CardPlacementHandler
# True while the player holds toggle_map_display (Ctrl) to hide rune icons.
var _runes_hidden: bool = false
var _challenge_highlighted_coords: Array[Vector2i] = []
var _disabled_tile_coords: Array[Vector2i] = []


func _ready() -> void:
	_layout = HexMapLayout.new()
	_layout.setup(self)
	_apply_tile_spacing()
	generate_terrain()
	Events.turn_ended.connect(on_turn_ended)
	Events.rune_empowered.connect(_on_rune_empowered)
	Events.rune_empower_consumed.connect(_on_rune_empower_consumed)

	card_placement_handler = CardPlacementHandler.new()
	card_placement_handler.tile_map = self
	add_child(card_placement_handler)

	set_process(true)


func _process(_delta: float) -> void:
	var should_hide_runes := Input.is_action_pressed("toggle_map_display")
	if should_hide_runes == _runes_hidden:
		return
	_set_runes_hidden(should_hide_runes)


# Widen the hex grid cells while keeping 256px textures, creating visible gaps
func _apply_tile_spacing() -> void:
	var spaced_tile_size := Vector2i(
		HEX_TEXTURE_SIZE + hex_tile_gap,
		HEX_TEXTURE_SIZE + hex_tile_gap
	)
	for layer: TileMapLayer in [
		base_layer,
		selection_overlay_layer,
		card_drop_overlay_layer,
		disabled_tile_overlay_layer,
		fading_sector_overlay_layer,
	]:
		layer.tile_set.tile_size = spaced_tile_size


# Handles tile hover highlighting and selection clicks.
func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_processing_turn:
		return

	if not card_placement_handler.is_card_selected and event is InputEventMouseMotion:
		_update_hover_highlight()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_clear_selection()
			return

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click()


func _update_hover_highlight() -> void:
	var map_coords: Vector2i = _mouse_map_coords()
	if is_in_map(map_coords) and is_tile_interactable(map_coords):
		if map_coords == hovered_cell:
			return

		if hovered_cell != Vector2i(-1, -1) and hovered_cell != selected_cell:
			selection_overlay_layer.set_cell(hovered_cell, -1)

		hovered_cell = map_coords
		if map_coords != selected_cell:
			selection_overlay_layer.set_cell(
				map_coords,
				HOVER_OVERLAY_SOURCE_ID,
				OVERLAY_TILE_ATLAS_COORDS
			)
		else:
			# Selected tile already shows the selection overlay; skip hover.
			hovered_cell = Vector2i(-1, -1)
	elif hovered_cell != Vector2i(-1, -1) and hovered_cell != selected_cell:
		selection_overlay_layer.set_cell(hovered_cell, -1)
		hovered_cell = Vector2i(-1, -1)


func _handle_left_click() -> void:
	var map_coords: Vector2i = _mouse_map_coords()
	if not is_in_map(map_coords) or not is_tile_interactable(map_coords):
		_clear_selection()
		return

	if not card_placement_handler.is_card_selected:
		tile_panel.set_hex(map_data[map_coords])

	if map_coords != selected_cell:
		selection_overlay_layer.set_cell(selected_cell, -1)

	if hovered_cell == map_coords:
		selection_overlay_layer.set_cell(hovered_cell, -1)
		hovered_cell = Vector2i(-1, -1)

	if not card_placement_handler.is_card_selected:
		selection_overlay_layer.set_cell(
			map_coords,
			SELECTED_OVERLAY_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		selected_cell = map_coords


func _clear_selection() -> void:
	tile_panel.hide()
	selection_overlay_layer.set_cell(selected_cell, -1)
	selected_cell = Vector2i(-1, -1)


func _mouse_map_coords() -> Vector2i:
	return base_layer.local_to_map(to_local(get_global_mouse_position()))


func is_in_map(coords: Vector2i) -> bool:
	return map_data.has(coords)


# Disabled difficulty tiles exist on the map but cannot be selected, hovered, or played on.
func is_tile_interactable(coords: Vector2i) -> bool:
	if not is_in_map(coords):
		return false
	return not map_data[coords].is_disabled_by_difficulty


# Returns map-adjacent hex tiles that exist on this map (0–6 neighbors).
func get_adjacent_hexes(coords: Vector2i) -> Array[Hex]:
	var neighbors: Array[Hex] = []
	for direction in HexMapLayout.NEIGHBORS:
		var neighbor_coords: Vector2i = base_layer.get_neighbor_cell(coords, direction)
		if map_data.has(neighbor_coords):
			neighbors.append(map_data[neighbor_coords])
	return neighbors


# Outer ring tiles have at least one hex neighbor direction that leaves the map.
func is_edge_tile(coords: Vector2i) -> bool:
	for direction in HexMapLayout.NEIGHBORS:
		var neighbor_coords: Vector2i = base_layer.get_neighbor_cell(coords, direction)
		if not map_data.has(neighbor_coords):
			return true
	return false


# Every rune currently placed on the map. Pass rune_type to filter by PRODUCER or SUPPORT.
func get_all_placed_runes(rune_type: Variant = null) -> Array[Rune]:
	var runes: Array[Rune] = []
	for hex: Hex in map_data.values():
		if hex.active_rune != null and hex.active_rune.type == rune_type:
			runes.append(hex.active_rune)
	return runes


# Hex tiles that currently hold a rune.
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


# Adjacent map tiles occupied by a rune. Pass rune_type to filter by PRODUCER or SUPPORT.
func count_occupied_adjacent_hexes(coords: Vector2i, rune_type: Variant = null) -> int:
	var count := 0
	for hex: Hex in get_adjacent_hexes(coords):
		if hex.active_rune == null:
			continue
		if rune_type != null and hex.active_rune.type != rune_type:
			continue
		count += 1
	return count


# Occupied runes on map-adjacent hexes around tile.
func get_adjacent_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	var result: Array[Rune] = []
	for hex: Hex in get_adjacent_hexes(tile.coordinates):
		if hex.active_rune == null:
			continue
		if filter_type != null and hex.active_rune.type != filter_type:
			continue
		result.append(hex.active_rune)
	return result


# Adjacent runes sorted in the map's global trigger order.
func get_adjacent_runes_in_trigger_order(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	var result: Array[Rune] = []
	var neighbors := get_adjacent_hexes(tile.coordinates)
	for hex: Hex in get_hexes_in_trigger_order():
		if hex.active_rune == null:
			continue
		if not neighbors.has(hex):
			continue
		if filter_type != null and hex.active_rune.type != filter_type:
			continue
		result.append(hex.active_rune)
	return result


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
	disabled_tile_overlay_layer.clear()
	fading_sector_overlay_layer.clear()
	_disabled_tile_coords.clear()

	var hex_center := Vector2i(hex_size, hex_size)
	_place_hex_tile(hex_center)

	# Expand ring-by-ring using Godot's hex neighbor graph for a symmetric hexagon
	var frontier: Array[Vector2i] = [hex_center]
	for _ring in hex_size:
		var next_frontier: Array[Vector2i] = []
		for cell in frontier:
			for direction in HexMapLayout.NEIGHBORS:
				var neighbor: Vector2i = base_layer.get_neighbor_cell(cell, direction)
				if map_data.has(neighbor):
					continue
				_place_hex_tile(neighbor)
				next_frontier.append(neighbor)
		frontier = next_frontier

	_layout.reset(hex_center)
	_assign_segment_passive_modifiers()
	_apply_difficulty_disabled_tiles()


# Randomly disable tiles for difficulty level 5, excluding segment-passive tiles.
func _apply_difficulty_disabled_tiles() -> void:
	var disable_count := Difficulty.get_disabled_tile_count(GameManager.selected_difficulty)
	if disable_count <= 0:
		return

	var candidates: Array[Vector2i] = []
	for coords: Vector2i in map_data:
		var hex: Hex = map_data[coords]
		if hex.is_reserved_for_segment_passive():
			continue
		candidates.append(coords)

	candidates.shuffle()
	disable_count = mini(disable_count, candidates.size())

	for i in disable_count:
		var coords := candidates[i]
		var hex: Hex = map_data[coords]
		hex.is_disabled_by_difficulty = true
		disabled_tile_overlay_layer.set_cell(
			coords,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_disabled_tile_coords.append(coords)


# Stamp each character's segment passive onto reserved map tiles at run start.
func _assign_segment_passive_modifiers() -> void:
	var modifier := SegmentPassiveModifier.create_for_character(GameManager.selected_character)

	match GameManager.selected_character:
		PlayerCharacter.Type.SURVEYOR, PlayerCharacter.Type.ENCIRCLER:
			# First tile of every row (Surveyor) or ring (Encircler) segment.
			for segment: Array in _layout.build_segments():
				if segment.is_empty():
					continue
				map_data[segment[0]].set_segment_passive_modifier(modifier)
		PlayerCharacter.Type.SPIRALIST:
			map_data[_layout.get_hex_center()].set_segment_passive_modifier(modifier)


func _set_runes_hidden(hide_runes: bool) -> void:
	_runes_hidden = hide_runes
	for hex: Hex in map_data.values():
		hex.set_runes_hidden(hide_runes)


# Ring index from the map center (0 = center, hex_size = outer edge).
func get_tile_ring_distance(coords: Vector2i) -> int:
	return _layout.get_ring_distance(coords)


func get_coords_in_trigger_order() -> Array[Vector2i]:
	return _layout.get_coords_in_trigger_order()


func get_hexes_in_trigger_order() -> Array[Hex]:
	return _layout.get_hexes_in_trigger_order()


func get_segment_index(coords: Vector2i) -> int:
	return _layout.get_segment_index(coords)


func get_runes_on_same_segment_as(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_runes_on_segment(get_segment_index(tile.coordinates), filter_type)


func get_runes_on_segment(segment_index: int, filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_runes_on_segment(segment_index, filter_type)


func get_segment_count() -> int:
	return _layout.build_segments().size()


func get_hexes_in_segment(segment_index: int) -> Array[Hex]:
	var hexes: Array[Hex] = []
	if segment_index < 0:
		return hexes

	for hex: Hex in map_data.values():
		if get_segment_index(hex.coordinates) == segment_index:
			hexes.append(hex)
	return hexes


func highlight_challenge_segment(segment_index: int) -> void:
	clear_challenge_segment_highlight()
	if segment_index < 0:
		return

	for coords: Vector2i in map_data:
		if get_segment_index(coords) != segment_index:
			continue
		fading_sector_overlay_layer.set_cell(
			coords,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_challenge_highlighted_coords.append(coords)


func clear_challenge_segment_highlight() -> void:
	for coords: Vector2i in _challenge_highlighted_coords:
		fading_sector_overlay_layer.set_cell(coords, -1)
	_challenge_highlighted_coords.clear()


func get_runes_on_first_tile_of_each_segment(filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_runes_on_first_tile_of_each_segment(filter_type)


func get_runes_on_last_tile_of_each_segment(filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_runes_on_last_tile_of_each_segment(filter_type)


func get_first_or_last_rune_in_segment(
	tile: Hex,
	segment_offset: int,
	first: bool,
	filter_type: Variant = null
) -> Rune:
	return _layout.get_first_or_last_rune_in_segment(tile, segment_offset, first, filter_type)


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
	var start := current_index - 1 if before else current_index + 1
	var end := -1 if before else runes_in_order.size()
	var step := -1 if before else 1

	for i in range(start, end, step):
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


func queue_rune_triggers(runes: Array[Rune], activation_scales: Array[float] = []) -> void:
	for i in range(runes.size()):
		var scale_rune := 1.0
		if i < activation_scales.size():
			scale_rune = activation_scales[i]
		_pending_trigger_queue.append({
			"rune": runes[i],
			"activation_scale": scale_rune,
		})


func create_floating_text(pos: Vector2, text: String, is_gold: bool) -> void:
	var floating_text = preload("res://scenes/animations/floating_text.tscn").instantiate()
	floating_text.position = pos
	floating_text.set_text(text, is_gold)
	get_tree().current_scene.add_child(floating_text)


# Resolve enhancement output after a short pause so its floating text reads separately.
const ENHANCEMENT_ACTIVATION_DELAY := 0.5


func schedule_delayed_enhancement_activation(host_rune: Rune, tile: Hex, output_scale: float) -> void:
	_play_delayed_enhancement_activation(host_rune, tile, output_scale)


func _play_delayed_enhancement_activation(host_rune: Rune, tile: Hex, output_scale: float) -> void:
	await get_tree().create_timer(ENHANCEMENT_ACTIVATION_DELAY / GameManager.game_speed).timeout
	if tile.active_rune != host_rune or host_rune.enhancement == null:
		return

	host_rune._activation_output_scale = output_scale
	host_rune.enhancement.activate(host_rune, tile)
	host_rune._activation_output_scale = 1.0


# Used for setting camera boundaries and other coordinate conversions.
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)


func _on_rune_empowered(rune: Rune) -> void:
	AudioManager.play_sfx(UI_SOUNDS.EMPOWER)
	var hex := get_hex_for_rune(rune)
	if hex != null:
		hex.start_empower_flash()


func _on_rune_empower_consumed(rune: Rune) -> void:
	var hex := get_hex_for_rune(rune)
	if hex != null:
		hex.stop_empower_flash()


func on_turn_ended() -> void:
	var base_delay_interval := 0.5
	_pending_trigger_queue.clear()

	for tile: Hex in get_hexes_in_trigger_order():
		if tile.active_rune == null:
			continue

		var delay_interval := base_delay_interval / GameManager.game_speed
		await _resolve_rune_activation(tile)
		await get_tree().create_timer(delay_interval).timeout

	GameManager.finish_turn_processing()


# Resolve one tile: primary activation, then any queued secondary triggers.
func _resolve_rune_activation(tile: Hex) -> void:
	await _activate_rune_on_tile(tile, 1.0, false)

	while not _pending_trigger_queue.is_empty():
		var entry: Dictionary = _pending_trigger_queue.pop_front()
		var target_hex := get_hex_for_rune(entry["rune"])
		if target_hex == null or target_hex.active_rune == null:
			continue
		await _activate_rune_on_tile(target_hex, entry["activation_scale"], true)


func _activate_rune_on_tile(tile: Hex, activation_scale: float = 1.0, from_trigger: bool = false) -> void:
	if tile.active_rune == null or tile.is_disabled_by_difficulty:
		return

	if not from_trigger and ChallengeManager.should_skip_primary_producer_activation(tile.active_rune):
		return

	activation_scale *= SegmentPassive.get_activation_scale(tile)
	activation_scale *= ChallengeManager.get_producer_output_multiplier(tile)
	var activation_count: int = SegmentPassive.get_activation_count(tile)

	for _activation_index in activation_count:
		if tile.active_rune == null:
			return

		if tile.active_rune.is_active:
			tile.play_rune_activation_animation()
			await _wait_for_activation_animation()

		tile.apply_rune_activation(activation_scale)
		SegmentPassive.apply_post_activation_effects(tile)


func _wait_for_activation_animation() -> void:
	var duration := RuneUI.ACTIVATION_POP_DURATION + RuneUI.ACTIVATION_SETTLE_DURATION
	await get_tree().create_timer(duration / GameManager.game_speed).timeout
