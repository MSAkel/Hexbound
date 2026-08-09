class_name HexTileMap
extends Node2D

# Live map state: tiles, runes, turn flow, UI

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
# Tiles currently lit during the post-turn segment result reveal.
var _segment_reveal_glow_coords: Array[Vector2i] = []

const SEGMENT_REVEAL_GLOW_COLOR := Color(1.35, 1.05, 0.25, 1.0)
const SEGMENT_REVEAL_PAUSE := 0.35
# Keep in sync with RuneUI segment reveal lift + slam durations.
const SEGMENT_REVEAL_ANIMATION_DURATION := 0.36


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


## True when coords belong to a tile on this map.
func is_in_map(coords: Vector2i) -> bool:
	return map_data.has(coords)


## Disabled difficulty tiles exist on the map but cannot be selected, hovered, or played on.
func is_tile_interactable(coords: Vector2i) -> bool:
	if not is_in_map(coords):
		return false
	return not map_data[coords].is_disabled_by_difficulty


## Returns map-adjacent hex tiles that exist on this map (up to six neighbors).
func get_all_adjacent_hexes(coords: Vector2i) -> Array[Hex]:
	var neighbors: Array[Hex] = []
	for direction in HexMapLayout.NEIGHBORS:
		var neighbor_coords: Vector2i = base_layer.get_neighbor_cell(coords, direction)
		if map_data.has(neighbor_coords):
			neighbors.append(map_data[neighbor_coords])
	return neighbors


## Outer ring tiles have at least one hex neighbor direction that leaves the map.
func is_edge_tile(coords: Vector2i) -> bool:
	for direction in HexMapLayout.NEIGHBORS:
		var neighbor_coords: Vector2i = base_layer.get_neighbor_cell(coords, direction)
		if not map_data.has(neighbor_coords):
			return true
	return false


## Every rune currently placed on the map. Pass rune_type to filter by PRODUCER or SUPPORT.
func get_all_placed_runes(rune_type: Variant = null) -> Array[Rune]:
	var runes: Array[Rune] = []
	for hex: Hex in map_data.values():
		if hex.active_rune == null:
			continue
		if rune_type != null and hex.active_rune.type != rune_type:
			continue
		runes.append(hex.active_rune)
	return runes


## Hex tiles that currently hold a rune.
func get_all_hexes_with_runes() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in map_data.values():
		if hex.active_rune != null:
			hexes.append(hex)
	return hexes


## Counts all adjacent tiles occupied by a rune. Pass rune_type to filter by type.
func count_all_occupied_adjacent_runes(coords: Vector2i, rune_type: Variant = null) -> int:
	var count := 0
	for hex: Hex in get_all_adjacent_hexes(coords):
		if hex.active_rune == null:
			continue
		if rune_type != null and hex.active_rune.type != rune_type:
			continue
		count += 1
	return count


## All runes on map-adjacent hexes around tile (unordered).
func get_all_adjacent_runes(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	var result: Array[Rune] = []
	for hex: Hex in get_all_adjacent_hexes(tile.coordinates):
		if hex.active_rune == null:
			continue
		if filter_type != null and hex.active_rune.type != filter_type:
			continue
		result.append(hex.active_rune)
	return result


## All adjacent runes sorted in the map's global trigger order.
func get_all_adjacent_runes_in_trigger_order(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	var result: Array[Rune] = []
	var neighbors := get_all_adjacent_hexes(tile.coordinates)
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


## Builds the hex map from the center tile outward and assigns segment passives.
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
	_layout.reset_turn_results()
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


## Ring index from the map center (0 = center, hex_size = outer edge).
func get_tile_ring_distance(coords: Vector2i) -> int:
	return _layout.get_ring_distance(coords)


## All map coordinates sorted by the active trigger-order rule.
func get_coords_in_trigger_order() -> Array[Vector2i]:
	return _layout.get_coords_in_trigger_order()


## All map hex tiles in trigger order.
func get_hexes_in_trigger_order() -> Array[Hex]:
	return _layout.get_hexes_in_trigger_order()


## Segment index for a tile under the active character grouping (-1 when unknown).
func get_segment_index(coords: Vector2i) -> int:
	return _layout.get_segment_index(coords)


## All placed runes on the same segment as tile, optionally filtered by rune type.
func get_all_runes_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_all_runes_on_segment(get_segment_index(tile.coordinates), filter_type)


## All placed runes on one segment by index, optionally filtered by rune type.
func get_all_runes_on_segment(segment_index: int, filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_all_runes_on_segment(segment_index, filter_type)


## All placed runes on other segments, optionally filtered by rune type.
func get_all_runes_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[Rune]:
	return _layout.get_all_runes_on_other_segments(tile, filter_type)

## Number of character-specific segments on the current map.
func get_segment_count() -> int:
	return _layout.build_segments().size()


## All hex tiles belonging to one segment index.
func get_hexes_in_segment(segment_index: int) -> Array[Hex]:
	var hexes: Array[Hex] = []
	if segment_index < 0:
		return hexes

	for hex: Hex in map_data.values():
		if get_segment_index(hex.coordinates) == segment_index:
			hexes.append(hex)
	return hexes


## Clears per-segment turn totals at the start of turn resolution.
func reset_segment_turn_results() -> void:
	_layout.reset_turn_results()
	Events.segment_turn_results_reset.emit()


## Records score produced by a rune on its tile's segment and updates global turn score.
func add_turn_score_for_tile(tile: Hex, amount: int) -> void:
	if amount == 0:
		return

	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_score(segment_index, amount)
	GameManager.turn_score += amount
	Events.segment_turn_results_changed.emit(
		segment_index,
		_layout.get_segment_turn_score(segment_index),
		_layout.get_segment_turn_gold(segment_index)
	)


## Records gold produced by a rune on its tile's segment and updates the gold pool.
func add_turn_gold_for_tile(tile: Hex, amount: int) -> void:
	if amount == 0:
		return

	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_gold(segment_index, amount)
	GoldManager.add(amount)
	Events.segment_turn_results_changed.emit(
		segment_index,
		_layout.get_segment_turn_score(segment_index),
		_layout.get_segment_turn_gold(segment_index)
	)


func get_segment_turn_score(segment_index: int) -> int:
	return _layout.get_segment_turn_score(segment_index)


func get_segment_turn_gold(segment_index: int) -> int:
	return _layout.get_segment_turn_gold(segment_index)


## Overlays every tile in a segment for challenge UI highlighting.
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


## Clears the challenge segment overlay stamped by highlight_challenge_segment().
func clear_challenge_segment_highlight() -> void:
	for coords: Vector2i in _challenge_highlighted_coords:
		fading_sector_overlay_layer.set_cell(coords, -1)
	_challenge_highlighted_coords.clear()


## First or last placed rune in a segment relative to tile's segment. See HexMapLayout.get_rune_in_relative_segment().
func get_rune_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> Rune:
	return _layout.get_rune_in_relative_segment(tile, segment_index_offset, pick_first_in_segment, filter_type)


func _build_all_runes_in_trigger_order() -> Array[Rune]:
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


## Rune on the next occupied hex in global trigger order (null when empty).
func get_next_rune_in_trigger_order(current_tile: Hex) -> Rune:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1 or current_index + 1 >= hexes.size():
		return null
	return hexes[current_index + 1].active_rune


## True when the next rune in trigger order can be consumed in-sequence this turn.
func can_consume_next_rune_in_trigger_order(current_tile: Hex) -> bool:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1 or current_index + 1 >= hexes.size():
		return false

	var next_rune := hexes[current_index + 1].active_rune
	if next_rune == null:
		return false

	# Every rune on earlier hexes must have already activated this turn.
	for i in range(current_index):
		var prior_rune := hexes[i].active_rune
		if prior_rune != null and not GameManager.has_rune_activated_this_turn(prior_rune):
			return false

	return not GameManager.has_rune_activated_this_turn(next_rune)


## Up to count runes that activate after current_tile in trigger order.
func get_next_runes_in_trigger_order(
	current_tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[Rune]:
	return _get_runes_relative_to_trigger_order(current_tile, count, false, filter_type)


## Up to count runes that activated before current_tile in trigger order.
func get_previous_runes_in_trigger_order(
	current_tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[Rune]:
	return _get_runes_relative_to_trigger_order(current_tile, count, true, filter_type)


func _get_runes_relative_to_trigger_order(
	current_tile: Hex,
	count: int,
	previous: bool,
	filter_type: Variant = null
) -> Array[Rune]:
	var runes_in_order := _build_all_runes_in_trigger_order()
	var current_index := -1
	for i in range(runes_in_order.size()):
		if runes_in_order[i] == current_tile.active_rune:
			current_index = i
			break

	if current_index == -1:
		return []

	var result: Array[Rune] = []
	var start := current_index - 1 if previous else current_index + 1
	var end := -1 if previous else runes_in_order.size()
	var step := -1 if previous else 1

	for i in range(start, end, step):
		var rune := runes_in_order[i]
		if filter_type != null and rune.type != filter_type:
			continue
		result.append(rune)
		if result.size() >= count:
			break
	return result


## Returns the hex tile that currently holds rune, or null when it is not placed.
func get_hex_for_rune(rune: Rune) -> Hex:
	for hex: Hex in map_data.values():
		if hex.active_rune == rune:
			return hex
	return null


## Removes a placed rune from its tile and cancels queued triggers targeting it.
func destroy_placed_rune(rune: Rune) -> void:
	var hex := get_hex_for_rune(rune)
	if hex == null:
		return

	hex.remove_rune()

	for i in range(_pending_trigger_queue.size() - 1, -1, -1):
		if _pending_trigger_queue[i]["rune"] == rune:
			_pending_trigger_queue.remove_at(i)


## Queues extra rune activations to resolve before the current tile flow continues.
func queue_rune_triggers(runes: Array[Rune], activation_scales: Array[float] = []) -> void:
	for i in range(runes.size()):
		var scale_rune := 1.0
		if i < activation_scales.size():
			scale_rune = activation_scales[i]
		_pending_trigger_queue.append({
			"rune": runes[i],
			"activation_scale": scale_rune,
		})


## Spawns floating combat text at a world position on the current scene.
func create_floating_text(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var floating_text = preload("res://scenes/animations/floating_text.tscn").instantiate()
	floating_text.position = pos
	floating_text.set_text(text, color)
	get_tree().current_scene.add_child(floating_text)


const ENHANCEMENT_ACTIVATION_DELAY := 0.5


## Delays enhancement resolution so its floating text does not overlap the host rune's text.
func schedule_delayed_enhancement_activation(host_rune: Rune, tile: Hex, output_scale: float) -> void:
	_play_delayed_enhancement_activation(host_rune, tile, output_scale)


func _play_delayed_enhancement_activation(host_rune: Rune, tile: Hex, output_scale: float) -> void:
	await get_tree().create_timer(ENHANCEMENT_ACTIVATION_DELAY / GameManager.game_speed).timeout
	if tile.active_rune != host_rune or host_rune.enhancement == null:
		return

	host_rune._activation_output_scale = output_scale
	host_rune.enhancement.activate(host_rune, tile)
	host_rune._activation_output_scale = 1.0


## Converts map coordinates to local pixel position on the base tile layer.
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


## Resolves every placed rune in trigger order when the player ends the turn.
func on_turn_ended() -> void:
	reset_segment_turn_results()

	var base_delay_interval := 0.5
	_pending_trigger_queue.clear()

	for tile: Hex in get_hexes_in_trigger_order():
		if tile.active_rune == null:
			continue

		var delay_interval := base_delay_interval / GameManager.game_speed
		await _resolve_rune_activation(tile)
		await get_tree().create_timer(delay_interval).timeout

	await _play_segment_turn_result_reveals()
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


## Plays the end-of-turn reveal for each segment that produced score or gold this turn.
func _play_segment_turn_result_reveals() -> void:
	for segment_index in get_segment_count():
		var score := get_segment_turn_score(segment_index)
		var gold := get_segment_turn_gold(segment_index)
		if score == 0 and gold == 0:
			continue
		await _play_single_segment_reveal(segment_index, score, gold)


## Highlights one segment, animates its runes, then shows a combined floating total.
func _play_single_segment_reveal(segment_index: int, score: int, gold: int) -> void:
	_apply_segment_reveal_glow(segment_index)

	for hex: Hex in get_hexes_in_segment(segment_index):
		if hex.active_rune != null:
			hex.play_segment_result_animation()

	await get_tree().create_timer(
		SEGMENT_REVEAL_ANIMATION_DURATION / GameManager.game_speed
	).timeout

	var summary_lines: PackedStringArray = []
	if score > 0:
		summary_lines.append("+%d Score" % score)
	if gold > 0:
		summary_lines.append("+%d Gold" % gold)
	create_floating_text(
		_get_segment_screen_center(segment_index),
		"\n".join(summary_lines), 
		Color(1.0, 0.85, 0.2, 1.0)
	)

	await get_tree().create_timer(SEGMENT_REVEAL_PAUSE / GameManager.game_speed).timeout
	_clear_segment_reveal_glow()
	await get_tree().create_timer(SEGMENT_REVEAL_PAUSE / GameManager.game_speed).timeout


func _apply_segment_reveal_glow(segment_index: int) -> void:
	_clear_segment_reveal_glow()
	fading_sector_overlay_layer.modulate = SEGMENT_REVEAL_GLOW_COLOR

	var segments := _layout.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return

	for coords: Vector2i in segments[segment_index]:
		fading_sector_overlay_layer.set_cell(
			coords,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_segment_reveal_glow_coords.append(coords)

func _clear_segment_reveal_glow() -> void:
	for coords: Vector2i in _segment_reveal_glow_coords:
		fading_sector_overlay_layer.set_cell(coords, -1)
	_segment_reveal_glow_coords.clear()
	fading_sector_overlay_layer.modulate = Color.WHITE


## Average tile position for segment-wide floating text placement.
func _get_segment_screen_center(segment_index: int) -> Vector2:
	var segments := _layout.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return Vector2.ZERO

	var center := Vector2.ZERO
	var segment: Array = segments[segment_index]
	for coords: Vector2i in segment:
		center += base_layer.map_to_local(coords)
	return center / segment.size()
