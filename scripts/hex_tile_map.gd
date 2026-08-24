class_name HexTileMap
extends Node2D

# Live map state: tiles, runes, turn flow, UI

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var tile_panel: TilePanel = $"../MainUI/TerrainTileUI"
@onready var base_layer: TileMapLayer = $BaseLayer
@onready var trigger_order_overlay: TriggerOrderOverlay = $TriggerOrderOverlay
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var rune_highlight_overlay_layer: TileMapLayer = $RuneHighlightOverlayLayer
@onready var disabled_tile_overlay_layer: TileMapLayer = $DisabledTileOverlayLayer
@onready var fading_sector_overlay_layer: TileMapLayer = $FadingSectorOverlayLayer

# Selection overlay uses source 0 for hover. Click-to-lock selection was removed.
const HOVER_OVERLAY_SOURCE_ID := 0
const OVERLAY_TILE_ATLAS_COORDS := Vector2i(0, 0)
# TileCard placement / trigger preview overlay on RuneHighlightOverlayLayer.
const RUNE_HIGHLIGHT_SOURCE_ID := 0
# Draw above hex tiles (0) and rune UI (resting 0, activation/reveal animations 10).
const RUNE_HIGHLIGHT_LAYER_Z_INDEX := 20
# Disabled and fading-sector layers each expose a single tile on source 0.
const OVERLAY_TILE_SOURCE_ID := 0

# Hexagon radius — tiles from center to each outer edge (hex_size=2 → 19 tiles)
@export_range(1, 20, 1) var hex_size: int = 2
# Extra pixels added to tile_size so adjacent hex visuals do not touch.
# Use a smaller X gap if rows look too far apart compared to the diagonal edges.
@export_range(0, 64, 1) var hex_tile_gap_x: int = 20
@export_range(0, 64, 1) var hex_tile_gap_y: int = 20

# Pointy-top hex art size. tile_size = this + the X/Y gaps for spacing on the grid.
const HEX_TEXTURE_SIZE := Vector2i(221, 255)
# Placed rune UI. Icons are still square with side padding and must stay centered on the cell.
const HEX_RUNE_SIZE := Vector2(256, 256)

# Atlas coords for the single dashed hex tile on BaseLayer (source 0)
const BASE_TILE_ATLAS_COORDS := Vector2i(0, 0)

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
# Tiles lit when a card credits another segment's turn total.
var _flashed_segment_coords: Array[Vector2i] = []
var _flash_segment_generation: int = 0

# Owners of cells on fading_sector_overlay_layer, used so one overlay does not erase another.
enum FadingOverlayOwner { CHALLENGE, REVEAL }

const SEGMENT_REVEAL_GLOW_COLOR := Color(1.35, 1.05, 0.25, 1.0)
const SEGMENT_REVEAL_PAUSE := 0.35
# Keep in sync with RuneUI segment reveal highlight + fade durations.
const SEGMENT_REVEAL_ANIMATION_DURATION := 0.36
# How long a destination-segment flash stays visible during card activation.
const SEGMENT_CREDIT_FLASH_DURATION := 0.5

# Delay before showing the tile info panel after hovering a tile with a placed card.
const TILE_PANEL_HOVER_DELAY := 0.4
# Soften the light-blue segment overlay while previewing an empty tile's segment.
const EMPTY_TILE_SEGMENT_HOVER_MODULATE := Color(1.0, 1.0, 1.0, 0.45)
# Tile currently being hovered for the info panel (independent of selection overlay).
var _tile_panel_hover_coords: Vector2i = Vector2i(-1, -1)
var _tile_panel_timer: Timer
# Empty tile whose segment is highlighted on the map (no tile panel).
var _empty_tile_segment_hover_coords: Vector2i = Vector2i(-1, -1)
# Occupied-tile inspect overlay from get_trigger_preview_coords.
var _inspect_highlight_coords: Array[Vector2i] = []
# First Energy × Mult equals beat in a tutorial run holds longer.
var _did_tutorial_product_linger: bool = false


func _ready() -> void:
	_layout = HexMapLayout.new()
	_layout.setup(self)
	# Keep the rune highlight above tiles and placed runes so segment/placement overlays stay visible.
	rune_highlight_overlay_layer.z_index = RUNE_HIGHLIGHT_LAYER_Z_INDEX
	_apply_tile_spacing()
	trigger_order_overlay.setup(self)
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


# Widen the hex grid cells while keeping the 221x255 textures, creating visible gaps.
func _apply_tile_spacing() -> void:
	var spaced_tile_size := Vector2i(
		HEX_TEXTURE_SIZE.x + hex_tile_gap_x,
		HEX_TEXTURE_SIZE.y + hex_tile_gap_y
	)
	for layer: TileMapLayer in [
		base_layer,
		selection_overlay_layer,
		rune_highlight_overlay_layer,
		disabled_tile_overlay_layer,
		fading_sector_overlay_layer,
	]:
		layer.tile_set.tile_size = spaced_tile_size


# Handles tile hover highlighting. Left-click no longer locks a selected hex.
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


func _update_hover_highlight() -> void:
	var map_coords: Vector2i = _mouse_map_coords()
	if is_in_map(map_coords) and is_tile_interactable(map_coords):
		if map_coords == hovered_cell:
			return

		if hovered_cell != Vector2i(-1, -1):
			selection_overlay_layer.set_cell(hovered_cell, -1)

		hovered_cell = map_coords
		selection_overlay_layer.set_cell(
			map_coords,
			HOVER_OVERLAY_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
	elif hovered_cell != Vector2i(-1, -1):
		selection_overlay_layer.set_cell(hovered_cell, -1)
		hovered_cell = Vector2i(-1, -1)


func _mouse_map_coords() -> Vector2i:
	return base_layer.local_to_map(to_local(get_global_mouse_position()))


# Start / refresh hover feedback for the tile under the cursor.
# Empty tiles highlight their segment. Occupied tiles show the tile info panel.
func _update_tile_panel_hover(map_coords: Vector2i) -> void:
	if not is_in_map(map_coords) or not is_tile_interactable(map_coords):
		_hide_tile_panel_hover()
		return

	var hex: Hex = map_data[map_coords]

	# Empty tiles have nothing for the panel. Preview the rest of the segment instead.
	if hex.active_tile_card == null:
		_hide_tile_panel_only()
		_update_empty_tile_segment_hover(map_coords)
		return

	_clear_empty_tile_segment_hover()

	if map_coords == _tile_panel_hover_coords:
		# Keep the panel glued to the tile while the camera zooms or pans.
		if tile_panel.visible:
			tile_panel.update_anchor(_get_tile_screen_rect(map_coords))
		return

	_tile_panel_hover_coords = map_coords
	_update_occupied_inspect_overlay(hex)
	tile_panel.hide()
	_tile_panel_timer.start()


# Hide the panel and stop its timer without clearing empty-tile segment preview.
func _hide_tile_panel_only() -> void:
	_tile_panel_hover_coords = Vector2i(-1, -1)
	_tile_panel_timer.stop()
	tile_panel.hide()
	_clear_occupied_inspect_overlay()


func _hide_tile_panel_hover() -> void:
	_hide_tile_panel_only()
	_clear_empty_tile_segment_hover()


# Light-blue overlay on every other tile in this empty tile's segment.
func _update_empty_tile_segment_hover(map_coords: Vector2i) -> void:
	var segment_index := get_segment_index(map_coords)
	# Re-apply if the coords match but another UI cleared the overlay meanwhile.
	if (
		map_coords == _empty_tile_segment_hover_coords
		and _hovered_segment_index == segment_index
	):
		return

	_empty_tile_segment_hover_coords = map_coords
	highlight_hovered_segment(
		segment_index,
		map_coords,
		EMPTY_TILE_SEGMENT_HOVER_MODULATE
	)


func _clear_empty_tile_segment_hover() -> void:
	if _empty_tile_segment_hover_coords == Vector2i(-1, -1):
		return

	var segment_index := get_segment_index(_empty_tile_segment_hover_coords)
	_empty_tile_segment_hover_coords = Vector2i(-1, -1)
	clear_hovered_segment_highlight(segment_index)


# Light tiles this placed card would affect. Skip the hovered cell, matching placement preview.
func _update_occupied_inspect_overlay(hex: Hex) -> void:
	_clear_occupied_inspect_overlay()
	if hex == null or hex.active_tile_card == null:
		return
	if card_placement_handler != null and card_placement_handler.is_card_selected:
		return

	var origin := hex.coordinates
	for coords: Vector2i in hex.active_tile_card.get_trigger_preview_coords(hex):
		if not is_in_map(coords):
			continue
		if coords == origin:
			continue
		rune_highlight_overlay_layer.set_cell(
			coords,
			RUNE_HIGHLIGHT_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_inspect_highlight_coords.append(coords)


func _clear_occupied_inspect_overlay() -> void:
	for coords: Vector2i in _inspect_highlight_coords:
		if _rune_highlight_still_needed(coords, false, false, true):
			continue
		rune_highlight_overlay_layer.set_cell(coords, -1)
	_inspect_highlight_coords.clear()


func _on_tile_panel_hover_timeout() -> void:
	if _tile_panel_hover_coords == Vector2i(-1, -1):
		return
	if not map_data.has(_tile_panel_hover_coords):
		return
	var hex: Hex = map_data[_tile_panel_hover_coords]
	# Panel is only for tiles with a placed card.
	if hex.active_tile_card == null:
		return
	tile_panel.set_hex(hex, _get_tile_screen_rect(_tile_panel_hover_coords))


func _on_card_drag_started_hide_tile_panel(_card: CardUI) -> void:
	_hide_tile_panel_hover()


# Convert a map cell into a viewport/CanvasLayer rect so the panel aligns with the camera.
func _get_tile_screen_rect(coords: Vector2i) -> Rect2:
	var tile_size := Vector2(HEX_TEXTURE_SIZE)
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


## Disabled difficulty tiles exist on the map but cannot be hovered or played on.
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


## Builds the hex map from the center tile outward.
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
	_empty_tile_segment_hover_coords = Vector2i(-1, -1)
	rune_highlight_overlay_layer.modulate = Color.WHITE

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
	_layout.reset_turn_results()
	# Disabled tiles are restored from the save file when continuing a run.
	if not RunSaveManager.should_restore_run():
		_apply_difficulty_disabled_tiles()
	trigger_order_overlay.rebuild()


# Randomly disable tiles for difficulty level 5.
func _apply_difficulty_disabled_tiles() -> void:
	var disable_count := Difficulty.get_disabled_tile_count(GameManager.selected_difficulty)
	if disable_count <= 0:
		return

	var candidates: Array[Vector2i] = []
	for coords: Vector2i in map_data:
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


func _on_map_display_layout_changed(layout: String) -> void:
	for hex: Hex in map_data.values():
		hex.set_map_display_layout(layout)
	# Order numbers are Controls, not atlas tiles. Toggle the overlay instead of a TileMapLayer.
	trigger_order_overlay.set_active(layout == "order_segments")


## Ring index from the map center (0 = center, hex_size = outer edge).
func get_tile_ring_distance(coords: Vector2i) -> int:
	return _layout.get_ring_distance(coords)


## Tile 180 degrees from coords around the map center.
func get_opposite_coords(coords: Vector2i) -> Vector2i:
	return _layout.get_opposite_coords(coords)


## Hex on the opposite side of the map, or null when that cell is missing.
func get_opposite_hex(coords: Vector2i) -> Hex:
	var opposite_coords := get_opposite_coords(coords)
	if not map_data.has(opposite_coords):
		return null
	return map_data[opposite_coords]


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


## Tile count for a segment index, or 0 when the index is invalid.
func get_segment_size(segment_index: int) -> int:
	return _layout.get_segment_size(segment_index)


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


## Records Energy produced by a rune on its tile's segment.
func add_turn_score_for_tile(tile: Hex, amount: int) -> void:
	add_turn_score_for_segment(get_segment_index(tile.coordinates), amount)


## Records Energy on a segment by index. Used when a card credits another segment.
func add_turn_score_for_segment(segment_index: int, amount: int) -> void:
	if amount == 0:
		return

	_layout.add_segment_turn_score(segment_index, amount)
	_emit_segment_turn_results_changed(segment_index)


## Records multiplier produced by a rune on its tile's segment.
func add_turn_multiplier_for_tile(tile: Hex, amount: int) -> void:
	add_turn_multiplier_for_segment(get_segment_index(tile.coordinates), amount)


## Records multiplier on a segment by index. Used when a card credits another segment.
func add_turn_multiplier_for_segment(segment_index: int, amount: int) -> void:
	if amount == 0:
		return

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


## Notifies UI of the latest per-segment Energy, multiplier, and Energy x Mult product.
func _emit_segment_turn_results_changed(segment_index: int) -> void:
	var score := _layout.get_segment_turn_score(segment_index)
	var multiplier := _layout.get_segment_turn_multiplier(segment_index)
	var gold := _layout.get_segment_turn_gold(segment_index)
	EventBus.segment_turn_results_changed.emit(segment_index, score, multiplier, score * multiplier, gold)


## Each segment scores independently (Energy x Mult), then products are summed for the turn.
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


## Activations on a segment this turn, including the activation currently resolving.
func get_segment_turn_trigger_count(segment_index: int) -> int:
	return _layout.get_segment_turn_trigger_count(segment_index)


## Records that a tile card on this tile is activating during turn resolution.
func record_segment_trigger_for_tile(tile: Hex) -> void:
	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_trigger(segment_index)


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


## Overlays tiles in a segment while its run-info row or an empty map tile is hovered.
## exclude_coords skips the hovered empty tile so the cream outline stays the focus.
func highlight_hovered_segment(
	segment_index: int,
	exclude_coords: Vector2i = Vector2i(-1, -1),
	overlay_modulate: Color = Color.WHITE
) -> void:
	# Full-segment UI-row hover replaces any empty-tile segment preview.
	if exclude_coords == Vector2i(-1, -1) and overlay_modulate == Color.WHITE:
		_empty_tile_segment_hover_coords = Vector2i(-1, -1)

	# Skip only when an unchanged full-segment UI-row hover is requested again.
	if (
		_hovered_segment_index == segment_index
		and exclude_coords == Vector2i(-1, -1)
		and overlay_modulate == Color.WHITE
	):
		return

	clear_hovered_segment_highlight()
	if segment_index < 0:
		return

	_hovered_segment_index = segment_index
	rune_highlight_overlay_layer.modulate = overlay_modulate
	for hex: Hex in get_hexes_in_segment(segment_index):
		var coords := hex.coordinates
		if coords == exclude_coords:
			continue
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
		# Leave cells that card placement or a credit flash still owns on this layer.
		if _rune_highlight_still_needed(coords, true, false):
			continue
		rune_highlight_overlay_layer.set_cell(coords, -1)
	_hovered_segment_coords.clear()
	_hovered_segment_index = -1
	# Restore full opacity unless placement or another owner still needs a custom modulate.
	if card_placement_handler == null or not card_placement_handler.is_card_selected:
		rune_highlight_overlay_layer.modulate = Color.WHITE


## Briefly lights a segment so the player can see where forwarded Energy or Mult landed.
func flash_segment_highlight(segment_index: int) -> void:
	_clear_flashed_segment_highlight()
	if segment_index < 0:
		return

	for hex: Hex in get_hexes_in_segment(segment_index):
		var coords := hex.coordinates
		rune_highlight_overlay_layer.set_cell(
			coords,
			RUNE_HIGHLIGHT_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_flashed_segment_coords.append(coords)

	_flash_segment_generation += 1
	var generation := _flash_segment_generation
	var duration := SEGMENT_CREDIT_FLASH_DURATION / GameManager.game_speed
	get_tree().create_timer(duration).timeout.connect(
		func() -> void:
			if generation != _flash_segment_generation:
				return
			_clear_flashed_segment_highlight()
	)


func _clear_flashed_segment_highlight() -> void:
	for coords: Vector2i in _flashed_segment_coords:
		if _rune_highlight_still_needed(coords, false, true):
			continue
		rune_highlight_overlay_layer.set_cell(coords, -1)
	_flashed_segment_coords.clear()


## True while hover, placement preview, a credit flash, or inspect still owns this overlay cell.
func _rune_highlight_still_needed(
	coords: Vector2i,
	from_hover: bool,
	from_flash: bool,
	from_inspect: bool = false
) -> bool:
	if card_placement_handler != null and card_placement_handler.is_highlighting_coord(coords):
		return true
	if not from_hover and coords in _hovered_segment_coords:
		return true
	if not from_flash and coords in _flashed_segment_coords:
		return true
	if not from_inspect and coords in _inspect_highlight_coords:
		return true
	return false


## True while a run-info segment row or credit flash is lighting this tile.
func has_hovered_segment_highlight_at(coords: Vector2i) -> bool:
	return (
		coords in _hovered_segment_coords
		or coords in _flashed_segment_coords
		or coords in _inspect_highlight_coords
	)


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


## Show floating text at a world position on the current scene.
func create_floating_text(pos: Vector2, text: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	var floating_text := _spawn_floating_text(pos, text, color, icon)
	floating_text.play_float_and_free()


func _spawn_floating_text(pos: Vector2, text: String, color: Color, icon: Texture2D = null) -> FloatingText:
	var floating_text := preload("res://scenes/animations/floating_text.tscn").instantiate() as FloatingText
	floating_text.position = pos
	get_tree().current_scene.add_child(floating_text)
	floating_text.set_text(text, color, icon)
	return floating_text


func _spawn_segment_product_text(pos: Vector2, score: int, multiplier: int) -> FloatingText:
	var floating_text := preload("res://scenes/animations/floating_text.tscn").instantiate() as FloatingText
	floating_text.position = pos
	get_tree().current_scene.add_child(floating_text)
	floating_text.set_segment_product(score, multiplier)
	return floating_text


## Runs the enhancement in the same activation. Card floats stack if both emit text.
func schedule_delayed_enhancement_activation(host_rune: TileCard, tile: Hex, output_scale: float) -> void:
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
	_emit_segment_turn_completed_snapshot()
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

	activation_scale *= ChallengeManager.get_producer_output_multiplier(tile)

	if tile.active_tile_card.is_active:
		tile.play_tile_card_activation_animation()
		await _wait_for_activation_animation()

	tile.apply_tile_card_activation(activation_scale)


func _wait_for_activation_animation() -> void:
	var duration := RuneUI.activation_animation_duration()
	await get_tree().create_timer(duration / GameManager.game_speed).timeout


## Plays the end-of-turn reveal for each segment that produced score, multiplier, or gold this turn.
func _play_segment_turn_result_reveals() -> void:
	var running_total := 0
	var revealed_any := false
	var handed_off_to_display := false
	for segment_index in get_segment_count():
		var score := get_segment_turn_score(segment_index)
		var multiplier := get_segment_turn_multiplier(segment_index)
		var gold := get_segment_turn_gold(segment_index)
		if score == 0 and gold == 0:
			continue
		var contribution := score * multiplier
		running_total += contribution
		var grow_into_display := contribution > 0 and not handed_off_to_display
		await _play_single_segment_reveal(segment_index, contribution, running_total, grow_into_display)
		if contribution > 0:
			handed_off_to_display = true
		revealed_any = true

	if not revealed_any:
		return

	var display := _get_turn_score_display()
	if display != null:
		await display.play_merge_into_round_info()


## Highlights one segment, animates its runes, then flies its Score product into the turn score overlay.
func _play_single_segment_reveal(
	segment_index: int,
	contribution: int,
	running_total: int,
	grow_into_display: bool
) -> void:
	_apply_segment_reveal_glow(segment_index)

	for hex: Hex in get_hexes_in_segment(segment_index):
		if hex.active_tile_card != null:
			hex.play_segment_result_animation()

	await get_tree().create_timer(
		SEGMENT_REVEAL_ANIMATION_DURATION / GameManager.game_speed
	).timeout

	if contribution > 0:
		await _play_segment_score_merge(segment_index, contribution, running_total, grow_into_display)

	await get_tree().create_timer(SEGMENT_REVEAL_PAUSE / GameManager.game_speed).timeout
	_clear_segment_reveal_glow()
	await get_tree().create_timer(SEGMENT_REVEAL_PAUSE / GameManager.game_speed).timeout


## Rises Energy x Mult, morphs into Score, unlocks the panel cell, then merges the product.
func _play_segment_score_merge(
	segment_index: int,
	contribution: int,
	running_total: int,
	grow_into_display: bool
) -> void:
	var score := get_segment_turn_score(segment_index)
	var multiplier := get_segment_turn_multiplier(segment_index)
	var floating_text := _spawn_segment_product_text(
		_get_segment_screen_center(segment_index),
		score,
		multiplier
	)
	await floating_text.play_rise()
	await floating_text.play_equals_to_product(contribution, _should_linger_on_product())

	EventBus.segment_score_revealed.emit(segment_index, contribution)

	var display := _get_turn_score_display()
	if display == null:
		floating_text.queue_free()
		return

	var target_world := _canvas_to_world(display.get_label_center_canvas())
	var target_font := ScoreReadoutStyle.font_size_for_score(running_total)
	await floating_text.merge_into(target_world, grow_into_display, target_font)

	if grow_into_display:
		display.appear_from_handoff(running_total)
		floating_text.queue_free()
	else:
		floating_text.queue_free()
		await display.present_running_total(running_total)


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


## Converts a viewport or CanvasLayer point into world space under the play camera.
func _canvas_to_world(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * canvas_pos


## Shared overlay that accumulates segment Score during the post-turn reveal.
func _get_turn_score_display() -> TurnScoreDisplay:
	return get_tree().get_first_node_in_group("turn_score_display") as TurnScoreDisplay


## First product beat in an active tutorial holds longer so Energy × Mult can be read.
func _should_linger_on_product() -> bool:
	if _did_tutorial_product_linger:
		return false
	for node in get_tree().get_nodes_in_group("tutorial_banner"):
		if node.has_method("is_tutorial_active") and node.is_tutorial_active():
			_did_tutorial_product_linger = true
			return true
	return false


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


## Packages per-segment turn totals for the segment-output history panel.
func capture_segment_turn_snapshot() -> Dictionary:
	var segments: Array = []
	var total_score := 0
	var total_gold := 0
	for segment_index in get_segment_count():
		var score := get_segment_turn_score(segment_index)
		var multiplier := get_segment_turn_multiplier(segment_index)
		var gold := get_segment_turn_gold(segment_index)
		var segment_total := score * multiplier
		segments.append({
			"score": score,
			"multiplier": multiplier,
			"total_score": segment_total,
			"gold": gold,
		})
		total_score += segment_total
		total_gold += gold
	return {
		"segments": segments,
		"total_score": total_score,
		"total_gold": total_gold,
	}


func _emit_segment_turn_completed_snapshot() -> void:
	EventBus.segment_turn_completed.emit(
		GameManager.get_turn_number(),
		capture_segment_turn_snapshot()
	)


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
