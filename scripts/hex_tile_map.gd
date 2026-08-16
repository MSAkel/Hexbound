class_name HexTileMap
extends Node2D

# Live map state: tiles, runes, turn flow, UI

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var tile_panel: TilePanel = $"../MainUI/TerrainTileUI"
@onready var base_layer: TileMapLayer = $BaseLayer
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var rune_highlight_overlay_layer: TileMapLayer = $RuneHighlightOverlayLayer
@onready var disabled_tile_overlay_layer: TileMapLayer = $DisabledTileOverlayLayer
@onready var fading_sector_overlay_layer: TileMapLayer = $FadingSectorOverlayLayer

# Selection overlay uses source 0 for hover and source 2 for the locked selection.
const HOVER_OVERLAY_SOURCE_ID := 0
const SELECTED_OVERLAY_SOURCE_ID := 2
const OVERLAY_TILE_ATLAS_COORDS := Vector2i(0, 0)
# TileCard placement / trigger preview overlay on RuneHighlightOverlayLayer.
const RUNE_HIGHLIGHT_SOURCE_ID := 0
# Draw above hex tiles (0) and rune UI (resting 0, activation/reveal animations 10).
const RUNE_HIGHLIGHT_LAYER_Z_INDEX := 20
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

var _challenge_highlighted_coords: Array[Vector2i] = []
var _disabled_tile_coords: Array[Vector2i] = []
# Tiles currently lit during the post-turn segment result reveal.
var _segment_reveal_glow_coords: Array[Vector2i] = []
# Tiles highlighted while hovering a segment-results row in the run-info panel.
var _hovered_segment_coords: Array[Vector2i] = []
var _hovered_segment_index: int = -1

# Owners of cells on fading_sector_overlay_layer, used so one overlay does not erase another.
enum FadingOverlayOwner { CHALLENGE, REVEAL }

const SEGMENT_REVEAL_GLOW_COLOR := Color(1.35, 1.05, 0.25, 1.0)
const SEGMENT_REVEAL_PAUSE := 0.35
# Keep in sync with RuneUI segment reveal highlight + fade durations.
const SEGMENT_REVEAL_ANIMATION_DURATION := 0.36

# Delay before showing the tile info panel after hovering a tile.
const TILE_PANEL_HOVER_DELAY := 0.4
# Tile currently being hovered for the info panel (independent of selection overlay).
var _tile_panel_hover_coords: Vector2i = Vector2i(-1, -1)
var _tile_panel_timer: Timer


func _ready() -> void:
	_layout = HexMapLayout.new()
	_layout.setup(self)
	# Keep the rune highlight above tiles and placed runes so segment/placement overlays stay visible.
	rune_highlight_overlay_layer.z_index = RUNE_HIGHLIGHT_LAYER_Z_INDEX
	_apply_tile_spacing()
	generate_terrain()
	EventBus.turn_ended.connect(on_turn_ended)
	EventBus.tile_card_empowered.connect(_on_tile_card_empowered)
	EventBus.tile_card_empower_consumed.connect(_on_tile_card_empower_consumed)
	EventBus.card_drag_started.connect(_on_card_drag_started_hide_tile_panel)
	EventBus.map_display_layout_changed.connect(_on_map_display_layout_changed)

	card_placement_handler = CardPlacementHandler.new()
	card_placement_handler.tile_map = self
	add_child(card_placement_handler)

	_tile_panel_timer = Timer.new()
	_tile_panel_timer.one_shot = true
	_tile_panel_timer.wait_time = TILE_PANEL_HOVER_DELAY
	_tile_panel_timer.timeout.connect(_on_tile_panel_hover_timeout)
	add_child(_tile_panel_timer)
	tile_panel.hide()

	set_process(true)


func _process(_delta: float) -> void:
	# Re-anchor while visible so zoom/pan mid-hover stays lined up with the tile.
	if tile_panel.visible and _tile_panel_hover_coords != Vector2i(-1, -1):
		tile_panel.update_anchor(_get_tile_screen_rect(_tile_panel_hover_coords))


# Widen the hex grid cells while keeping 256px textures, creating visible gaps
func _apply_tile_spacing() -> void:
	var spaced_tile_size := Vector2i(
		HEX_TEXTURE_SIZE + hex_tile_gap,
		HEX_TEXTURE_SIZE + hex_tile_gap
	)
	for layer: TileMapLayer in [
		base_layer,
		selection_overlay_layer,
		rune_highlight_overlay_layer,
		disabled_tile_overlay_layer,
		fading_sector_overlay_layer,
	]:
		layer.tile_set.tile_size = spaced_tile_size


# Handles tile hover highlighting and selection clicks.
func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_processing_turn:
		_hide_tile_panel_hover()
		return

	if event is InputEventMouseMotion:
		if card_placement_handler.is_card_selected:
			_hide_tile_panel_hover()
		else:
			_update_hover_highlight()
			_update_tile_panel_hover(_mouse_map_coords())

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
	selection_overlay_layer.set_cell(selected_cell, -1)
	selected_cell = Vector2i(-1, -1)


func _mouse_map_coords() -> Vector2i:
	return base_layer.local_to_map(to_local(get_global_mouse_position()))


# Start / refresh the hover-delay panel for the tile under the cursor.
func _update_tile_panel_hover(map_coords: Vector2i) -> void:
	if not is_in_map(map_coords) or not is_tile_interactable(map_coords):
		_hide_tile_panel_hover()
		return

	if map_coords == _tile_panel_hover_coords:
		# Keep the panel glued to the tile while the camera zooms or pans.
		if tile_panel.visible:
			tile_panel.update_anchor(_get_tile_screen_rect(map_coords))
		return

	_tile_panel_hover_coords = map_coords
	tile_panel.hide()
	_tile_panel_timer.start()


func _hide_tile_panel_hover() -> void:
	_tile_panel_hover_coords = Vector2i(-1, -1)
	_tile_panel_timer.stop()
	tile_panel.hide()


func _on_tile_panel_hover_timeout() -> void:
	if _tile_panel_hover_coords == Vector2i(-1, -1):
		return
	if not map_data.has(_tile_panel_hover_coords):
		return
	tile_panel.set_hex(
		map_data[_tile_panel_hover_coords],
		_get_tile_screen_rect(_tile_panel_hover_coords)
	)


func _on_card_drag_started_hide_tile_panel(_card: CardUI) -> void:
	_hide_tile_panel_hover()


# Convert a map cell into a viewport/CanvasLayer rect so the panel aligns with the camera.
func _get_tile_screen_rect(coords: Vector2i) -> Rect2:
	var tile_size := Vector2(HEX_TEXTURE_SIZE, HEX_TEXTURE_SIZE)
	var center_local: Vector2 = base_layer.map_to_local(coords)
	var top_left_local: Vector2 = center_local - tile_size * 0.5
	# Use the canvas transform so Camera2D position/zoom are included.
	var canvas_xform: Transform2D = base_layer.get_global_transform_with_canvas()
	var screen_pos: Vector2 = canvas_xform * top_left_local
	var screen_size: Vector2 = canvas_xform.basis_xform(tile_size).abs()
	return Rect2(screen_pos, screen_size)


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
func get_all_placed_tile_cards(rune_type: Variant = null) -> Array[TileCard]:
	var runes: Array[TileCard] = []
	for hex: Hex in map_data.values():
		if hex.active_tile_card == null:
			continue
		if rune_type != null and hex.active_tile_card.type != rune_type:
			continue
		runes.append(hex.active_tile_card)
	return runes


## Hex tiles that currently hold a rune.
func get_all_hexes_with_runes() -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in map_data.values():
		if hex.active_tile_card != null:
			hexes.append(hex)
	return hexes


## Counts all adjacent tiles occupied by a rune. Pass rune_type to filter by type.
func count_all_occupied_adjacent_tile_cards(coords: Vector2i, rune_type: Variant = null) -> int:
	var count := 0
	for hex: Hex in get_all_adjacent_hexes(coords):
		if hex.active_tile_card == null:
			continue
		if rune_type != null and hex.active_tile_card.type != rune_type:
			continue
		count += 1
	return count


## All runes on map-adjacent hexes around tile (unordered).
func get_all_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for hex: Hex in get_all_adjacent_hexes(tile.coordinates):
		if hex.active_tile_card == null:
			continue
		if filter_type != null and hex.active_tile_card.type != filter_type:
			continue
		result.append(hex.active_tile_card)
	return result


## All adjacent runes sorted in the map's global trigger order.
func get_all_adjacent_tile_cards_in_trigger_order(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var result: Array[TileCard] = []
	var neighbors := get_all_adjacent_hexes(tile.coordinates)
	for hex: Hex in get_hexes_in_trigger_order():
		if hex.active_tile_card == null:
			continue
		if not neighbors.has(hex):
			continue
		if filter_type != null and hex.active_tile_card.type != filter_type:
			continue
		result.append(hex.active_tile_card)
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
	rune_highlight_overlay_layer.clear()
	disabled_tile_overlay_layer.clear()
	fading_sector_overlay_layer.clear()
	_disabled_tile_coords.clear()
	_hovered_segment_coords.clear()
	_hovered_segment_index = -1

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
	# Disabled tiles are restored from the save file when continuing a run.
	if not RunSaveManager.should_restore_run():
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
	var character := GameManager.selected_character
	var modifier := SegmentPassiveModifier.create_for_character(character)
	if character != null and character.passive_places_on_center_tile:
		map_data[_layout.get_hex_center()].set_segment_passive_modifier(modifier)
		return

	for segment: Array in _layout.build_segments():
		if segment.is_empty():
			continue
		map_data[segment[0]].set_segment_passive_modifier(modifier)


func _on_map_display_layout_changed(layout: String) -> void:
	if layout == "base":
		_set_tile_cards_hidden(false)
	elif layout == "tile_passives":
		_set_tile_cards_hidden(true)
	elif layout == "order_segments":
		_set_tile_cards_hidden(true)


func _set_tile_cards_hidden(hide_runes: bool) -> void:
	for hex: Hex in map_data.values():
		hex.set_tile_cards_hidden(hide_runes)


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


## True when coords is the first tile in its segment (trigger-order start).
func is_first_tile_in_segment(coords: Vector2i) -> bool:
	return _layout.is_first_tile_in_segment(coords)


## True when coords is the last tile in its segment (trigger-order end).
func is_last_tile_in_segment(coords: Vector2i) -> bool:
	return _layout.is_last_tile_in_segment(coords)


## First tile coordinates in a segment, or Vector2i(-1, -1) when the index is invalid.
func get_first_tile_coords_in_segment(segment_index: int) -> Vector2i:
	return _layout.get_first_tile_coords_in_segment(segment_index)


## Last tile coordinates in a segment, or Vector2i(-1, -1) when the index is invalid.
func get_last_tile_coords_in_segment(segment_index: int) -> Vector2i:
	return _layout.get_last_tile_coords_in_segment(segment_index)


## All placed runes on the same segment as tile, optionally filtered by rune type.
func get_all_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return _layout.get_all_tile_cards_on_segment(get_segment_index(tile.coordinates), filter_type)


## All placed runes on one segment by index, optionally filtered by rune type.
func get_all_tile_cards_on_segment(segment_index: int, filter_type: Variant = null) -> Array[TileCard]:
	return _layout.get_all_tile_cards_on_segment(segment_index, filter_type)


## All placed runes on other segments, optionally filtered by rune type.
func get_all_tile_cards_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return _layout.get_all_tile_cards_on_other_segments(tile, filter_type)

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
	EventBus.segment_turn_results_reset.emit()


## Records score produced by a rune on its tile's segment.
func add_turn_score_for_tile(tile: Hex, amount: int) -> void:
	if amount == 0:
		return

	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_score(segment_index, amount)
	_emit_segment_turn_results_changed(segment_index)

## Records multiplier produced by a rune on its tile's segment.
func add_turn_multiplier_for_tile(tile: Hex, amount: int) -> void:
	if amount == 0:
		return

	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_multiplier(segment_index, amount)
	_emit_segment_turn_results_changed(segment_index)


## Records gold produced by a rune on its tile's segment and updates the gold pool.
func add_turn_gold_for_tile(tile: Hex, amount: int) -> void:
	if amount == 0:
		return

	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_gold(segment_index, amount)
	GoldManager.add(amount)
	_emit_segment_turn_results_changed(segment_index)


## Notifies UI of the latest per-segment score, multiplier, and score x multiplier total.
func _emit_segment_turn_results_changed(segment_index: int) -> void:
	var score := _layout.get_segment_turn_score(segment_index)
	var multiplier := _layout.get_segment_turn_multiplier(segment_index)
	var gold := _layout.get_segment_turn_gold(segment_index)
	EventBus.segment_turn_results_changed.emit(segment_index, score, multiplier, score * multiplier, gold)


## Each segment scores independently (score x multiplier), then totals are summed for the turn.
func _apply_segment_turn_totals_to_game_manager() -> void:
	var total := 0
	for segment_index in get_segment_count():
		total += get_segment_turn_score(segment_index) * get_segment_turn_multiplier(segment_index)
	GameManager.turn_score = total


func get_segment_turn_score(segment_index: int) -> int:
	return _layout.get_segment_turn_score(segment_index)


func get_segment_turn_multiplier(segment_index: int) -> int:
	return _layout.get_segment_turn_multiplier(segment_index)

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
		if _fading_overlay_still_needed(coords, FadingOverlayOwner.CHALLENGE):
			continue
		fading_sector_overlay_layer.set_cell(coords, -1)
	_challenge_highlighted_coords.clear()


## Overlays every tile in a segment while its run-info row is hovered.
func highlight_hovered_segment(segment_index: int) -> void:
	if _hovered_segment_index == segment_index:
		return

	clear_hovered_segment_highlight()
	if segment_index < 0:
		return

	_hovered_segment_index = segment_index
	for hex: Hex in get_hexes_in_segment(segment_index):
		var coords := hex.coordinates
		rune_highlight_overlay_layer.set_cell(
			coords,
			RUNE_HIGHLIGHT_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_hovered_segment_coords.append(coords)


## Clears the hover overlay. Pass segment_index so a row's mouse-exit cannot wipe a newer hover.
func clear_hovered_segment_highlight(segment_index: int = -1) -> void:
	if segment_index >= 0 and _hovered_segment_index != segment_index:
		return

	for coords: Vector2i in _hovered_segment_coords:
		# Leave cells that card placement is currently previewing on the same layer.
		if card_placement_handler != null and card_placement_handler.is_highlighting_coord(coords):
			continue
		rune_highlight_overlay_layer.set_cell(coords, -1)
	_hovered_segment_coords.clear()
	_hovered_segment_index = -1


## True while a run-info segment row is lighting this tile on RuneHighlightOverlayLayer.
func has_hovered_segment_highlight_at(coords: Vector2i) -> bool:
	return coords in _hovered_segment_coords


## True when another fading-sector overlay still owns this cell.
func _fading_overlay_still_needed(coords: Vector2i, owner: FadingOverlayOwner) -> bool:
	if owner != FadingOverlayOwner.CHALLENGE and coords in _challenge_highlighted_coords:
		return true
	if owner != FadingOverlayOwner.REVEAL and coords in _segment_reveal_glow_coords:
		return true
	return false


## First or last placed rune in a segment relative to tile's segment. See HexMapLayout.get_tile_card_in_relative_segment().
func get_tile_card_in_relative_segment(
	tile: Hex,
	segment_index_offset: int,
	pick_first_in_segment: bool,
	filter_type: Variant = null
) -> TileCard:
	return _layout.get_tile_card_in_relative_segment(tile, segment_index_offset, pick_first_in_segment, filter_type)


func _get_hex_trigger_order_index(current_tile: Hex) -> int:
	var hexes := get_hexes_in_trigger_order()
	for i in range(hexes.size()):
		if hexes[i] == current_tile:
			return i
	return -1


## TileCard on the next occupied hex in global trigger order (null when empty).
func get_next_tile_card_in_trigger_order(current_tile: Hex) -> TileCard:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1 or current_index + 1 >= hexes.size():
		return null
	return hexes[current_index + 1].active_tile_card


## True when the next rune in trigger order can be consumed in-sequence this turn.
func can_consume_next_tile_card_in_trigger_order(current_tile: Hex) -> bool:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1 or current_index + 1 >= hexes.size():
		return false

	var next_rune := hexes[current_index + 1].active_tile_card
	if next_rune == null:
		return false

	# Every rune on earlier hexes must have already activated this turn.
	for i in range(current_index):
		var prior_rune := hexes[i].active_tile_card
		if prior_rune != null and not GameManager.has_tile_card_activated_this_turn(prior_rune):
			return false

	return not GameManager.has_tile_card_activated_this_turn(next_rune)


## Up to count runes that activate after current_tile in trigger order.
func get_next_tile_cards_in_trigger_order(
	current_tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	return _get_tile_cards_relative_to_trigger_order(current_tile, count, false, filter_type)


## Up to count runes that activated before current_tile in trigger order.
func get_previous_tile_cards_in_trigger_order(
	current_tile: Hex,
	count: int = 1,
	filter_type: Variant = null
) -> Array[TileCard]:
	return _get_tile_cards_relative_to_trigger_order(current_tile, count, true, filter_type)


func _get_tile_cards_relative_to_trigger_order(
	current_tile: Hex,
	count: int,
	previous: bool,
	filter_type: Variant = null
) -> Array[TileCard]:
	# Walk hexes in trigger order so previews work on empty placement tiles too.
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1:
		return []

	var result: Array[TileCard] = []
	var start := current_index - 1 if previous else current_index + 1
	var end := -1 if previous else hexes.size()
	var step := -1 if previous else 1

	for i in range(start, end, step):
		var rune := hexes[i].active_tile_card
		if rune == null:
			continue
		if filter_type != null and rune.type != filter_type:
			continue
		result.append(rune)
		if result.size() >= count:
			break
	return result


## Returns the hex tile that currently holds rune, or null when it is not placed.
func get_hex_for_tile_card(rune: TileCard) -> Hex:
	for hex: Hex in map_data.values():
		if hex.active_tile_card == rune:
			return hex
	return null


## Removes a placed rune from its tile and cancels queued triggers targeting it.
func destroy_placed_tile_card(rune: TileCard) -> void:
	var hex := get_hex_for_tile_card(rune)
	if hex == null:
		return

	hex.remove_tile_card()

	for i in range(_pending_trigger_queue.size() - 1, -1, -1):
		if _pending_trigger_queue[i]["rune"] == rune:
			_pending_trigger_queue.remove_at(i)


## Queues extra rune activations to resolve before the current tile flow continues.
func queue_tile_card_triggers(runes: Array[TileCard], activation_scales: Array[float] = []) -> void:
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
func schedule_delayed_enhancement_activation(host_rune: TileCard, tile: Hex, output_scale: float) -> void:
	_play_delayed_enhancement_activation(host_rune, tile, output_scale)


func _play_delayed_enhancement_activation(host_rune: TileCard, tile: Hex, output_scale: float) -> void:
	await get_tree().create_timer(ENHANCEMENT_ACTIVATION_DELAY / GameManager.game_speed).timeout
	if tile.active_tile_card != host_rune or host_rune.enhancement == null:
		return

	host_rune._activation_output_scale = output_scale
	host_rune.enhancement.activate(host_rune, tile)
	host_rune._activation_output_scale = 1.0


## Converts map coordinates to local pixel position on the base tile layer.
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)


func _on_tile_card_empowered(rune: TileCard) -> void:
	AudioManager.play_sfx(UI_SOUNDS.EMPOWER)
	var hex := get_hex_for_tile_card(rune)
	if hex != null:
		hex.start_empower_flash()


func _on_tile_card_empower_consumed(rune: TileCard) -> void:
	var hex := get_hex_for_tile_card(rune)
	if hex != null:
		hex.stop_empower_flash()


## Resolves every placed rune in trigger order when the player ends the turn.
func on_turn_ended() -> void:
	reset_segment_turn_results()

	var base_delay_interval := 0.5
	_pending_trigger_queue.clear()

	for tile: Hex in get_hexes_in_trigger_order():
		if tile.active_tile_card == null:
			continue

		var delay_interval := base_delay_interval / GameManager.game_speed
		await _resolve_rune_activation(tile)
		await get_tree().create_timer(delay_interval).timeout

	await _play_segment_turn_result_reveals()
	_apply_segment_turn_totals_to_game_manager()
	GameManager.finish_turn_processing()


# Resolve one tile: primary activation, then any queued secondary triggers.
func _resolve_rune_activation(tile: Hex) -> void:
	await _activate_tile_card_on_tile(tile, 1.0, false)

	while not _pending_trigger_queue.is_empty():
		var entry: Dictionary = _pending_trigger_queue.pop_front()
		var target_hex := get_hex_for_tile_card(entry["rune"])
		if target_hex == null or target_hex.active_tile_card == null:
			continue
		await _activate_tile_card_on_tile(target_hex, entry["activation_scale"], true)


func _activate_tile_card_on_tile(tile: Hex, activation_scale: float = 1.0, from_trigger: bool = false) -> void:
	if tile.active_tile_card == null or tile.is_disabled_by_difficulty:
		return

	if not from_trigger and ChallengeManager.should_skip_primary_producer_activation(tile.active_tile_card):
		return

	activation_scale *= SegmentPassive.get_activation_scale(tile)
	activation_scale *= ChallengeManager.get_producer_output_multiplier(tile)
	var activation_count: int = SegmentPassive.get_activation_count(tile)

	for _activation_index in activation_count:
		if tile.active_tile_card == null:
			return

		if tile.active_tile_card.is_active:
			tile.play_tile_card_activation_animation()
			await _wait_for_activation_animation()

		tile.apply_tile_card_activation(activation_scale)
		SegmentPassive.apply_post_activation_effects(tile)


func _wait_for_activation_animation() -> void:
	var duration := RuneUI.ACTIVATION_POP_DURATION + RuneUI.ACTIVATION_SETTLE_DURATION
	await get_tree().create_timer(duration / GameManager.game_speed).timeout


## Plays the end-of-turn reveal for each segment that produced score, multiplier, or gold this turn.
func _play_segment_turn_result_reveals() -> void:
	for segment_index in get_segment_count():
		var score := get_segment_turn_score(segment_index)
		var multiplier := get_segment_turn_multiplier(segment_index)
		var gold := get_segment_turn_gold(segment_index)
		if score == 0 and gold == 0:
			continue
		await _play_single_segment_reveal(segment_index, score, multiplier, gold)


## Highlights one segment, animates its runes, then shows a combined floating total.
func _play_single_segment_reveal(segment_index: int, score: int, multiplier: int, gold: int) -> void:
	_apply_segment_reveal_glow(segment_index)

	for hex: Hex in get_hexes_in_segment(segment_index):
		if hex.active_tile_card != null:
			hex.play_segment_result_animation()

	await get_tree().create_timer(
		SEGMENT_REVEAL_ANIMATION_DURATION / GameManager.game_speed
	).timeout

	var summary_lines: PackedStringArray = []
	if score > 0:
		summary_lines.append("+%d Score" % score)
	if multiplier > 0:
		summary_lines.append("+%d Mult" % multiplier)
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
		if _fading_overlay_still_needed(coords, FadingOverlayOwner.REVEAL):
			continue
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


#region Run save / load

func capture_map_state() -> Dictionary:
	var disabled_coords: Array = []
	for coords: Vector2i in _disabled_tile_coords:
		disabled_coords.append([coords.x, coords.y])

	var placed_runes: Array = []
	for coords: Vector2i in map_data:
		var hex: Hex = map_data[coords]
		if hex.active_tile_card == null:
			continue
		var entry := _serialize_placed_tile_card(hex.active_tile_card)
		entry["coords"] = [coords.x, coords.y]
		placed_runes.append(entry)

	return {
		"disabled_coords": disabled_coords,
		"placed_runes": placed_runes,
		"segment_turn_results": _layout.capture_turn_results(),
	}


func restore_map_state(state: Dictionary) -> void:
	_restore_disabled_tiles(state.get("disabled_coords", []))

	for entry: Dictionary in state.get("placed_runes", []):
		var coords_data: Array = entry.get("coords", [])
		if coords_data.size() < 2:
			continue
		var coords := Vector2i(int(coords_data[0]), int(coords_data[1]))
		if not map_data.has(coords):
			continue

		var rune := _deserialize_placed_tile_card(entry)
		if rune == null:
			continue
		map_data[coords].restore_placed_tile_card(rune)

	_layout.apply_turn_results(state.get("segment_turn_results", {}))


func refresh_segment_turn_results_ui() -> void:
	for segment_index in get_segment_count():
		_emit_segment_turn_results_changed(segment_index)


func _restore_disabled_tiles(coords_list: Array) -> void:
	for coords: Vector2i in _disabled_tile_coords:
		if map_data.has(coords):
			map_data[coords].is_disabled_by_difficulty = false

	_disabled_tile_coords.clear()
	disabled_tile_overlay_layer.clear()

	for coords_data: Variant in coords_list:
		if coords_data is not Array or coords_data.size() < 2:
			continue
		var coords := Vector2i(int(coords_data[0]), int(coords_data[1]))
		if not map_data.has(coords):
			continue

		var hex: Hex = map_data[coords]
		hex.is_disabled_by_difficulty = true
		disabled_tile_overlay_layer.set_cell(
			coords,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_disabled_tile_coords.append(coords)


func _serialize_placed_tile_card(rune: TileCard) -> Dictionary:
	var data := {
		"rune_id": rune.id,
		"activation_count": rune.activation_count,
		"is_active": rune.is_active,
		"bonus_production_amount": rune.bonus_production_amount,
		"is_empowered": rune.is_empowered,
		"enhancement_id": "",
	}
	if rune.enhancement != null:
		data["enhancement_id"] = rune.enhancement.id
	return data


func _deserialize_placed_tile_card(data: Dictionary) -> TileCard:
	var template := GameManager.get_tile_card_by_id(data.get("rune_id", ""))
	if template == null:
		return null

	var rune := template.duplicate(true)
	rune.activation_count = int(data.get("activation_count", 0))
	rune.is_active = bool(data.get("is_active", true))
	rune.bonus_production_amount = int(data.get("bonus_production_amount", 0))
	rune.is_empowered = bool(data.get("is_empowered", false))

	var enhancement_id: String = data.get("enhancement_id", "")
	if not enhancement_id.is_empty():
		var enhancement_template := GameManager.get_enhancement_by_id(enhancement_id)
		if enhancement_template != null:
			rune.enhancement = enhancement_template.duplicate(true)
	return rune

#endregion
