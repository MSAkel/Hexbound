class_name HexTileMap
extends Node2D

# Live map state: tiles, runes, overlays, and save. Turn resolve and hover UI live on helpers.

var hover_ui: HexHoverUI
var turn_resolver: HexTurnResolver

@onready var tile_panel: TilePanel = get_node_or_null("../MainUI/TerrainTileUI")
@onready var base_layer: TileMapLayer = $BaseLayer
@onready var trigger_order_overlay: TriggerOrderOverlay = $TriggerOrderOverlay
@onready var segment_path_overlay: SegmentPathOverlay = $SegmentPathOverlay
@onready var trigger_link_overlay: TriggerLinkOverlay = $TriggerLinkOverlay
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var hovered_tile_overlay_layer: TileMapLayer = $HoveredTileOverlayLayer
@onready var placement_valid_overlay_layer: TileMapLayer = $PlacementValidOverlayLayer
@onready var rune_highlight_overlay_layer: TileMapLayer = $RuneHighlightOverlayLayer
@onready var disabled_tile_overlay_layer: TileMapLayer = $DisabledTileOverlayLayer
@onready var fading_sector_overlay_layer: TileMapLayer = $FadingSectorOverlayLayer

# Selection overlay tileset sources in hex_tile_map.tscn.
const HOVER_OVERLAY_NORMAL := 0
const HOVER_OVERLAY_FIRST := 1
const HOVER_OVERLAY_LAST := 2
const HOVER_OVERLAY_BOTH := 3
const HOVERED_TILE_OVERLAY_SOURCE_ID := 0
const OVERLAY_TILE_ATLAS_COORDS := Vector2i(0, 0)
# Light white wash on the tile under the cursor so it stands out within a highlighted segment.
const HOVERED_TILE_OVERLAY_MODULATE := Color(0.9, 0.9, 0.9, 0.45)
# Valid placement targets for restricted cards such as edge, first, or last segment tiles.
const PLACEMENT_VALID_OVERLAY_SOURCE_ID := HOVER_OVERLAY_NORMAL
const PLACEMENT_VALID_OVERLAY_MODULATE := Color(0.45, 0.88, 1.15, 0.72)
# TileCard trigger preview overlay on RuneHighlightOverlayLayer.
const RUNE_HIGHLIGHT_SOURCE_ID := 0
# Tile-shaped overlays sit under rune icons. Trigger-order numbers stay above at z 25.
const TILE_OVERLAY_LAYER_Z_INDEX := 0
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
# Ring distances, trigger order, and segment grouping.
var _layout: HexMapLayout

# Card placement handler
var card_placement_handler: CardPlacementHandler

var _event_highlighted_coords: Array[Vector2i] = []
var _disabled_tile_coords: Array[Vector2i] = []
# Empty tiles locked by the Sealed Hexes event. Shares the disabled overlay layer.
var _event_sealed_coords: Array[Vector2i] = []
# Tiles currently lit during the post-turn segment result reveal.
var _segment_reveal_glow_coords: Array[Vector2i] = []
# Tiles highlighted while hovering a segment-results row in the run-info panel.
var _hovered_segment_coords: Array[Vector2i] = []
var _hovered_segment_index: int = -1
# Sticky trigger-order numbers from the layout button.
var _sticky_order_numbers: bool = false
# Temporary trigger-order numbers while Tab is held.
var _peek_order_numbers: bool = false
# Valid placement target while a hand card is selected.
var _placement_preview_cell: Vector2i = Vector2i(-1, -1)
# Tiles lit when a card credits another segment's turn total.
var _flashed_segment_coords: Array[Vector2i] = []
var _flash_segment_generation: int = 0
## Occupied tiles lit while aiming a tile-target potion.
var _potion_target_coords: Array[Vector2i] = []

# Owners of cells on fading_sector_overlay_layer, used so one overlay does not erase another.
enum FadingOverlayOwner { EVENT, REVEAL }

const SEGMENT_REVEAL_GLOW_COLOR := Color(1.35, 1.05, 0.25, 1.0)
# How long a destination-segment flash stays visible during card activation.
const SEGMENT_CREDIT_FLASH_DURATION := 0.5

# Occupied-tile inspect overlay from get_trigger_preview_coords.
var _inspect_highlight_coords: Array[Vector2i] = []


func _ready() -> void:
	_layout = HexMapLayout.new()
	_layout.setup(self)
	# Hex fills stay under card icons. Order numbers on TriggerOrderOverlay sit above both.
	rune_highlight_overlay_layer.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	placement_valid_overlay_layer.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	hovered_tile_overlay_layer.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	hovered_tile_overlay_layer.self_modulate = HOVERED_TILE_OVERLAY_MODULATE
	placement_valid_overlay_layer.modulate = PLACEMENT_VALID_OVERLAY_MODULATE
	_apply_tile_spacing()
	trigger_order_overlay.setup(self)
	segment_path_overlay.setup(self)
	trigger_link_overlay.setup(self)
	generate_terrain()
	EventBus.turn_ended.connect(on_turn_ended)
	EventBus.map_display_layout_changed.connect(_on_map_display_layout_changed)
	EventBus.potion_fuses_changed.connect(_refresh_potion_fuse_badges)

	card_placement_handler = CardPlacementHandler.new()
	card_placement_handler.tile_map = self
	add_child(card_placement_handler)

	# Headless playtests have no TerrainTileUI. Hover setup would null-deref.
	if tile_panel != null:
		hover_ui = HexHoverUI.new()
		hover_ui.name = "HoverUI"
		add_child(hover_ui)
		hover_ui.setup(self)

	turn_resolver = HexTurnResolver.new()
	turn_resolver.name = "TurnResolver"
	add_child(turn_resolver)
	turn_resolver.setup(self)


func _refresh_potion_fuse_badges() -> void:
	for hex: Hex in map_data.values():
		if hex.rune_ui != null and hex.active_tile_card != null:
			hex.rune_ui.refresh_potion_badges(hex.active_tile_card, hex.coordinates)


func _exit_tree() -> void:
	_free_map_hexes()


# Widen the hex grid cells while keeping the 221x255 textures, creating visible gaps.
func _apply_tile_spacing() -> void:
	var spaced_tile_size := Vector2i(
		HEX_TEXTURE_SIZE.x + hex_tile_gap_x,
		HEX_TEXTURE_SIZE.y + hex_tile_gap_y
	)
	for layer: TileMapLayer in [
		base_layer,
		selection_overlay_layer,
		hovered_tile_overlay_layer,
		placement_valid_overlay_layer,
		rune_highlight_overlay_layer,
		disabled_tile_overlay_layer,
		fading_sector_overlay_layer,
	]:
		layer.tile_set.tile_size = spaced_tile_size


# Handles tile hover highlighting. Left-click no longer locks a selected hex.
func _input(event: InputEvent) -> void:
	# Run before GUI focus navigation so Tab still peeks after clicking layout buttons.
	if event.is_action_pressed("peek_trigger_order"):
		_set_peek_order_numbers(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("peek_trigger_order"):
		_set_peek_order_numbers(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_processing_turn:
		dismiss_hover_feedback()
		return

	if event is InputEventMouseMotion:
		if card_placement_handler.is_card_selected:
			# CardPlacementHandler drives tile-panel inspect during placement drag.
			pass
		else:
			_update_hover_highlight()
			if hover_ui != null:
				hover_ui.update_tile_panel_hover(_mouse_map_coords())


func _update_hover_highlight() -> void:
	var map_coords: Vector2i = _mouse_map_coords()
	var previous_hovered := hovered_cell

	if is_in_map(map_coords) and is_tile_interactable(map_coords):
		if map_coords == hovered_cell:
			return
		hovered_cell = map_coords
	else:
		hovered_cell = Vector2i(-1, -1)

	if hovered_cell != previous_hovered:
		_refresh_map_focus_overlays()


func _mouse_map_coords() -> Vector2i:
	return base_layer.local_to_map(to_local(get_global_mouse_position()))


func _clear_selection_hover_highlight() -> void:
	if hovered_cell == Vector2i(-1, -1):
		return
	hovered_cell = Vector2i(-1, -1)
	_refresh_map_focus_overlays()


## Dismisses any map hover feedback when gameplay is covered by another UI.
func dismiss_hover_feedback() -> void:
	if hover_ui != null:
		hover_ui.hide_tile_panel()
	_clear_selection_hover_highlight()


func _set_peek_order_numbers(active: bool) -> void:
	if _peek_order_numbers == active:
		return
	_peek_order_numbers = active
	_refresh_map_focus_overlays()


func _is_order_view_active() -> bool:
	return _sticky_order_numbers or _peek_order_numbers


## Refreshes trigger-order numbers, segment role tints, tile emphasis, and dashed outlines.
func _refresh_map_focus_overlays() -> void:
	_refresh_trigger_order_overlay()


func _refresh_trigger_order_overlay() -> void:
	var overlay_on := _is_order_view_active()
	trigger_order_overlay.set_full_reveal(overlay_on)
	# Paths share the order/segments and Tab peek gate. They stay off during idle hover.
	segment_path_overlay.set_visible_for_order_view(overlay_on)
	if overlay_on:
		trigger_order_overlay.clear_focus()
	else:
		var focus_cell := _get_map_focus_cell()
		if focus_cell != Vector2i(-1, -1):
			trigger_order_overlay.set_focus_coords(focus_cell, true)
		else:
			trigger_order_overlay.clear_focus()
	_refresh_segment_role_highlights()
	refresh_dashed_outlines()


func set_placement_preview_cell(coords: Vector2i) -> void:
	if _placement_preview_cell == coords:
		return
	_placement_preview_cell = coords
	_refresh_map_focus_overlays()


func clear_placement_preview() -> void:
	set_placement_preview_cell(Vector2i(-1, -1))


## Cyan wash for legal placement tiles while a restricted card is selected.
func stamp_placement_valid_highlight(coords: Vector2i) -> void:
	placement_valid_overlay_layer.set_cell(
		coords,
		PLACEMENT_VALID_OVERLAY_SOURCE_ID,
		OVERLAY_TILE_ATLAS_COORDS
	)


func clear_placement_valid_highlights() -> void:
	placement_valid_overlay_layer.clear()


func _get_map_focus_cell() -> Vector2i:
	if _placement_preview_cell != Vector2i(-1, -1):
		return _placement_preview_cell
	return hovered_cell


func _refresh_segment_role_highlights() -> void:
	selection_overlay_layer.clear()

	# Tab peek and the layout toggle show every segment at once.
	if _is_order_view_active():
		for coords: Vector2i in map_data:
			_stamp_segment_role_selection(coords)
	else:
		var focus_cell := _get_map_focus_cell()
		if focus_cell != Vector2i(-1, -1):
			# Hover or placement preview lights one segment with first/last/both tints.
			var segment_index := get_segment_index(focus_cell)
			if segment_index >= 0:
				for hex: Hex in get_hexes_in_segment(segment_index):
					# The placement ghost occupies this cell. Do not wash it with the hex fill.
					if hex.coordinates == _placement_preview_cell:
						continue
					_stamp_segment_role_selection(hex.coordinates)

	_refresh_hovered_tile_emphasis()


## Hides the dashed hex outline during the full order overlay, or when a card occupies the tile.
func refresh_dashed_outlines() -> void:
	for coords: Vector2i in map_data:
		if _should_hide_dashed_outline(coords):
			base_layer.set_cell(coords, -1)
		else:
			base_layer.set_cell(coords, 0, BASE_TILE_ATLAS_COORDS)
	trigger_order_overlay.refresh_display_state()


func _should_hide_dashed_outline(coords: Vector2i) -> bool:
	# Hover numbers keep the dashed outline. Tab and the layout toggle hide every tile.
	if _is_order_view_active():
		return true
	var hex: Hex = map_data[coords]
	return hex.active_tile_card != null


func _refresh_hovered_tile_emphasis() -> void:
	hovered_tile_overlay_layer.clear()
	var emphasis_cell := _get_map_focus_cell()
	if emphasis_cell == Vector2i(-1, -1):
		return
	if not is_in_map(emphasis_cell) or not is_tile_interactable(emphasis_cell):
		return
	hovered_tile_overlay_layer.set_cell(
		emphasis_cell,
		HOVERED_TILE_OVERLAY_SOURCE_ID,
		OVERLAY_TILE_ATLAS_COORDS
	)


func _stamp_segment_role_selection(coords: Vector2i) -> void:
	selection_overlay_layer.set_cell(
		coords,
		_get_selection_hover_source_id(coords),
		OVERLAY_TILE_ATLAS_COORDS
	)


func _get_selection_hover_source_id(coords: Vector2i) -> int:
	var is_start := is_first_tile_in_segment(coords)
	var is_end := is_last_tile_in_segment(coords)
	if is_start and is_end:
		return HOVER_OVERLAY_BOTH
	if is_start:
		return HOVER_OVERLAY_FIRST
	if is_end:
		return HOVER_OVERLAY_LAST
	return HOVER_OVERLAY_NORMAL


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


## Disabled difficulty tiles and event-sealed tiles exist on the map but cannot be played on.
func is_tile_interactable(coords: Vector2i) -> bool:
	if not is_in_map(coords):
		return false
	return not map_data[coords].is_placement_blocked()


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
		if not is_tile_card_triggerable(hex):
			continue
		if rune_type != null and hex.active_tile_card.type != rune_type:
			continue
		runes.append(hex.active_tile_card)
	return runes


## True when a placed rune can fire during its own trigger-order slot this turn.
func is_tile_card_active(hex: Hex) -> bool:
	if hex == null or hex.active_tile_card == null:
		return false
	if hex.is_disabled_by_difficulty:
		return false
	return hex.active_tile_card.is_active


## Inactive and difficulty-disabled runes are skipped instantly during trigger order.
func _is_bypassed_in_trigger_order(hex: Hex) -> bool:
	if hex.active_tile_card == null:
		return false
	return not is_tile_card_active(hex)


## True when another card may queue or target this rune this turn.
func is_tile_card_triggerable(hex: Hex) -> bool:
	if not is_tile_card_active(hex):
		return false
	# Overdrive and a Mirror Copy facing it only fire from trigger order.
	return hex.active_tile_card.can_be_triggered_by_other_card(hex)


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
		if not is_tile_card_triggerable(hex):
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
		if not is_tile_card_triggerable(hex):
			continue
		if filter_type != null and hex.active_tile_card.type != filter_type:
			continue
		result.append(hex.active_tile_card)
	return result


## Adjacent hexes that activate after this tile in trigger order, including empty tiles.
## Returned earliest-first so the first adjacent Following card is always result[0].
func get_following_adjacent_hexes(tile: Hex) -> Array[Hex]:
	var result: Array[Hex] = []
	var self_index := _get_hex_trigger_order_index(tile)
	if self_index < 0:
		return result
	var neighbors := get_all_adjacent_hexes(tile.coordinates)
	for hex: Hex in get_hexes_in_trigger_order():
		if hex == tile:
			continue
		if not neighbors.has(hex):
			continue
		if _get_hex_trigger_order_index(hex) > self_index:
			result.append(hex)
	return result


## Occupied adjacent Following hexes, optionally filtered by card type.
func get_following_adjacent_tile_cards(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for hex: Hex in get_following_adjacent_hexes(tile):
		if hex.active_tile_card == null:
			continue
		if not is_tile_card_triggerable(hex):
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
		if not is_tile_card_triggerable(hex):
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
	_free_map_hexes()
	base_layer.clear()
	selection_overlay_layer.clear()
	hovered_tile_overlay_layer.clear()
	placement_valid_overlay_layer.clear()
	_placement_preview_cell = Vector2i(-1, -1)
	rune_highlight_overlay_layer.clear()
	disabled_tile_overlay_layer.clear()
	fading_sector_overlay_layer.clear()
	_disabled_tile_coords.clear()
	_hovered_segment_coords.clear()
	_hovered_segment_index = -1
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
	trigger_order_overlay.rebuild()
	segment_path_overlay.rebuild()


## Frees Hex UI Controls and drops dict refs so Nodes/RefCounted tiles cannot pile up.
func _free_map_hexes() -> void:
	for hex: Hex in map_data.values():
		if hex != null:
			hex.dispose()
	map_data.clear()


## Apply difficulty-driven map randomization after run RNG setup rolls.
func apply_run_start_randomization() -> void:
	if RunSaveManager.should_restore_run():
		return
	_apply_difficulty_disabled_tiles()


# Randomly disable tiles for difficulty level 5.
func _apply_difficulty_disabled_tiles() -> void:
	var disable_count := Difficulty.get_disabled_tile_count(GameManager.selected_difficulty)
	if disable_count <= 0:
		return

	var candidates: Array[Vector2i] = []
	for coords: Vector2i in map_data:
		candidates.append(coords)

	# Sort first so dictionary iteration order cannot change which tiles are disabled.
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	RunRng.shuffle_with(RunRng.create_rng("map_setup"), candidates)
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


## Stamps the disabled overlay on empty tiles locked by Sealed Hexes. Skips difficulty tiles.
func set_event_sealed_overlay(coords: Array[Vector2i]) -> void:
	clear_event_sealed_overlay()
	for cell: Vector2i in coords:
		if not is_in_map(cell):
			continue
		if cell in _disabled_tile_coords:
			continue
		disabled_tile_overlay_layer.set_cell(
			cell,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_event_sealed_coords.append(cell)


## Removes Sealed Hexes overlay cells without wiping difficulty-disabled tiles.
func clear_event_sealed_overlay() -> void:
	for cell: Vector2i in _event_sealed_coords:
		if cell in _disabled_tile_coords:
			continue
		disabled_tile_overlay_layer.set_cell(cell, -1)
	_event_sealed_coords.clear()


## True when the disabled overlay currently belongs to Sealed Hexes rather than difficulty.
func has_event_sealed_overlay_at(coords: Vector2i) -> bool:
	return coords in _event_sealed_coords


func _on_map_display_layout_changed(layout: String) -> void:
	_sticky_order_numbers = layout == "order_segments"
	_refresh_map_focus_overlays()


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


func build_segments() -> Array[Array]:
	return _layout.build_segments()


## All placed runes on the same segment as tile, optionally filtered by rune type.
func get_all_tile_cards_on_same_segment(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return _layout.get_all_tile_cards_on_segment(get_segment_index(tile.coordinates), filter_type)


## All placed runes on one segment by index, optionally filtered by rune type.
func get_all_tile_cards_on_segment(segment_index: int, filter_type: Variant = null) -> Array[TileCard]:
	return _layout.get_all_tile_cards_on_segment(segment_index, filter_type)


## All placed runes on other segments, optionally filtered by rune type.
func get_all_tile_cards_on_other_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	return _layout.get_all_tile_cards_on_other_segments(tile, filter_type)


## Cards on segments after this tile's segment.
func get_all_tile_cards_on_later_segments(tile: Hex, filter_type: Variant = null) -> Array[TileCard]:
	var current_index := get_segment_index(tile.coordinates)
	var result: Array[TileCard] = []
	if current_index < 0:
		return result
	for segment_index in range(current_index + 1, get_segment_count()):
		for card: TileCard in get_all_tile_cards_on_segment(segment_index, filter_type):
			result.append(card)
	return result


## Playable tiles in a segment that currently have no card.
## A placement-preview cell counts as occupied so hover chips match the tile after you drop.
func get_empty_tile_count_in_segment(segment_index: int) -> int:
	var empty := 0
	for hex: Hex in get_hexes_in_segment(segment_index):
		if hex.is_disabled_by_difficulty:
			continue
		if hex.coordinates == _placement_preview_cell:
			continue
		if hex.active_tile_card == null:
			empty += 1
	return empty


func mark_segment_resolved(segment_index: int) -> void:
	_layout.mark_segment_resolved(segment_index)


func is_segment_resolved(segment_index: int) -> bool:
	return _layout.is_segment_resolved(segment_index)


func mark_segment_received_relay(segment_index: int) -> void:
	_layout.mark_segment_received_relay(segment_index)


func count_segments_that_received_relay() -> int:
	return _layout.count_segments_that_received_relay()


func get_segment_breaks(segment_index: int) -> int:
	return _layout.get_segment_breaks(segment_index)


## Records a break on the card's segment and notifies remaining cards on that line.
func notify_card_broke(tile_card: TileCard) -> void:
	var hex := get_hex_for_tile_card(tile_card)
	if hex == null:
		return
	var segment_index := get_segment_index(hex.coordinates)
	_layout.add_segment_break(segment_index)
	for other: Hex in get_hexes_in_segment(segment_index):
		var card := other.active_tile_card
		if card == null or card == tile_card:
			continue
		card.on_other_segment_card_broke(tile_card, other)

## Number of character-specific segments on the current map.
func get_segment_count() -> int:
	return _layout.build_segments().size()


## Ordered coordinate lists for every segment in trigger order.
func get_ordered_segments() -> Array[Array]:
	return _layout.build_segments()


## All hex tiles belonging to one segment index.
func get_hexes_in_segment(segment_index: int) -> Array[Hex]:
	var hexes: Array[Hex] = []
	var segments := _layout.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return hexes

	for coords: Vector2i in segments[segment_index]:
		var hex: Hex = map_data.get(coords)
		if hex != null:
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
func add_turn_multiplier_for_tile(tile: Hex, amount: float) -> void:
	add_turn_multiplier_for_segment(get_segment_index(tile.coordinates), amount)


## Records multiplier on a segment by index. Used when a card credits another segment.
func add_turn_multiplier_for_segment(segment_index: int, amount: float) -> void:
	if is_zero_approx(amount):
		return

	_layout.add_segment_turn_multiplier(segment_index, amount)
	_emit_segment_turn_results_changed(segment_index)


## Records gold produced by a rune on its tile's segment and updates the gold pool.
func add_turn_gold_for_tile(tile: Hex, amount: int) -> void:
	if amount == 0:
		return
	# Austerity must not credit the segment ledger either, or the HUD would lie.
	if not EventManager.can_gain_gold():
		return

	var segment_index := get_segment_index(tile.coordinates)
	_layout.add_segment_turn_gold(segment_index, amount)
	GoldManager.add(amount)
	_emit_segment_turn_results_changed(segment_index)


## Records gold on a segment by index. Used when a drink relays gold to the next segment.
func add_turn_gold_for_segment(segment_index: int, amount: int) -> void:
	if amount == 0:
		return
	if not EventManager.can_gain_gold():
		return
	_layout.add_segment_turn_gold(segment_index, amount)
	GoldManager.add(amount)
	_emit_segment_turn_results_changed(segment_index)


## Notifies UI of the latest per-segment Energy, multiplier, and scored contribution.
func _emit_segment_turn_results_changed(segment_index: int, use_passive_adjustments: bool = false) -> void:
	var score := _layout.get_segment_turn_score(segment_index)
	var multiplier := _layout.get_segment_turn_multiplier(segment_index)
	var gold := _layout.get_segment_turn_gold(segment_index)
	if use_passive_adjustments:
		var breakdown := GameManager.get_segment_turn_contribution_breakdown(
			segment_index,
			score,
			multiplier
		)
		EventBus.segment_turn_results_changed.emit(
			segment_index,
			breakdown.display_energy,
			breakdown.display_multiplier,
			breakdown.contribution,
			gold
		)
		return
	EventBus.segment_turn_results_changed.emit(segment_index, score, multiplier, int(round(float(score) * multiplier)), gold)


## Each segment scores independently (Energy x Mult), then products are summed for the turn.
func _apply_segment_turn_totals_to_game_manager() -> void:
	GameManager.passive_runtime.on_turn_resolved(self)
	var total := 0
	var contributions: Array[int] = []
	for segment_index in get_segment_count():
		var score := get_segment_turn_score(segment_index)
		var multiplier := get_segment_turn_multiplier(segment_index)
		var contribution := GameManager.compute_segment_turn_contribution(segment_index, score, multiplier)
		contributions.append(contribution)
		total += contribution
	GameManager.record_turn_segment_peaks(contributions)
	GameManager.turn_score = total


func _check_full_map_cards_achievement() -> void:
	for coords: Vector2i in map_data.keys():
		var hex: Hex = map_data[coords]
		if hex.is_disabled_by_difficulty:
			continue
		if hex.active_tile_card == null:
			return
	GameManager.mark_full_map_cards_achieved()


func get_segment_turn_score(segment_index: int) -> int:
	return _layout.get_segment_turn_score(segment_index)


func get_segment_turn_multiplier(segment_index: int) -> float:
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


## Overlays every tile in a segment for event UI highlighting.
func highlight_event_segment(segment_index: int) -> void:
	clear_event_segment_highlight()
	if segment_index < 0:
		return

	var segments := _layout.build_segments()
	if segment_index >= segments.size():
		return
	for coords: Vector2i in segments[segment_index]:
		fading_sector_overlay_layer.set_cell(
			coords,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_event_highlighted_coords.append(coords)


## Clears the event segment overlay stamped by highlight_event_segment().
func clear_event_segment_highlight() -> void:
	for coords: Vector2i in _event_highlighted_coords:
		if _fading_overlay_still_needed(coords, FadingOverlayOwner.EVENT):
			continue
		fading_sector_overlay_layer.set_cell(coords, -1)
	_event_highlighted_coords.clear()


## Overlays tiles in a segment while its run-info row is hovered.
func highlight_hovered_segment(segment_index: int) -> void:
	# Skip only when the same UI-row hover is requested again.
	if _hovered_segment_index == segment_index:
		return

	clear_hovered_segment_highlight()
	if segment_index < 0:
		return

	_hovered_segment_index = segment_index
	rune_highlight_overlay_layer.modulate = Color.WHITE
	for hex: Hex in get_hexes_in_segment(segment_index):
		rune_highlight_overlay_layer.set_cell(
			hex.coordinates,
			RUNE_HIGHLIGHT_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)
		_hovered_segment_coords.append(hex.coordinates)


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
	GameManager.create_pauseable_timer(duration).timeout.connect(
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


## Lights occupied tiles while a tile-target potion is being aimed.
func set_potion_target_highlights(coords: Array[Vector2i]) -> void:
	clear_potion_target_highlights()
	_potion_target_coords = coords.duplicate()
	rune_highlight_overlay_layer.modulate = Color(0.55, 1.15, 0.85, 1.0)
	for cell in _potion_target_coords:
		rune_highlight_overlay_layer.set_cell(
			cell,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)


func clear_potion_target_highlights() -> void:
	var previous := _potion_target_coords.duplicate()
	_potion_target_coords.clear()
	for cell in previous:
		if _rune_highlight_still_needed(cell, false, false):
			continue
		rune_highlight_overlay_layer.set_cell(cell, -1)
	rune_highlight_overlay_layer.modulate = Color.WHITE


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
	if coords in _potion_target_coords:
		return true
	return false


## True while a run-info segment row, credit flash, or inspect is lighting this tile.
func has_hovered_segment_highlight_at(coords: Vector2i) -> bool:
	return (
		coords in _hovered_segment_coords
		or coords in _flashed_segment_coords
		or coords in _inspect_highlight_coords
		or coords in _potion_target_coords
	)


## True when another fading-sector overlay still owns this cell.
func _fading_overlay_still_needed(coords: Vector2i, owner: FadingOverlayOwner) -> bool:
	if owner != FadingOverlayOwner.EVENT and coords in _event_highlighted_coords:
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
	if current_index == -1:
		return null

	for i in range(current_index + 1, hexes.size()):
		var next_hex := hexes[i]
		if next_hex.active_tile_card == null or _is_bypassed_in_trigger_order(next_hex):
			continue
		return next_hex.active_tile_card
	return null


## True when the next rune in trigger order can be consumed in-sequence this turn.
func can_consume_next_tile_card_in_trigger_order(current_tile: Hex) -> bool:
	var hexes := get_hexes_in_trigger_order()
	var current_index := _get_hex_trigger_order_index(current_tile)
	if current_index == -1:
		return false

	# Every earlier rune that will actually fire must have already activated this turn.
	for i in range(current_index):
		var prior_hex := hexes[i]
		var prior_rune := prior_hex.active_tile_card
		if prior_rune == null or _is_bypassed_in_trigger_order(prior_hex):
			continue
		if not GameManager.has_tile_card_activated_this_turn(prior_rune):
			return false

	for i in range(current_index + 1, hexes.size()):
		var next_hex := hexes[i]
		var next_rune := next_hex.active_tile_card
		if next_rune == null or _is_bypassed_in_trigger_order(next_hex):
			continue
		return not GameManager.has_tile_card_activated_this_turn(next_rune)

	return false


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
		var hex := hexes[i]
		var rune := hex.active_tile_card
		if rune == null or _is_bypassed_in_trigger_order(hex):
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


## Moves two placed cards onto each other's tiles without duplicating their resources.
func swap_placed_tile_cards(hex_a: Hex, hex_b: Hex) -> void:
	if hex_a == null or hex_b == null or hex_a == hex_b:
		return
	var card_a := hex_a.active_tile_card
	var card_b := hex_b.active_tile_card
	if card_a == null or card_b == null:
		return
	hex_a.remove_tile_card()
	hex_b.remove_tile_card()
	hex_a.restore_placed_tile_card(card_b)
	hex_b.restore_placed_tile_card(card_a)


## Removes a placed rune from its tile and cancels queued triggers targeting it.
func destroy_placed_tile_card(rune: TileCard) -> void:
	turn_resolver.destroy_placed_tile_card(rune)


## Queues extra rune activations to resolve before the current tile flow continues.
func queue_tile_card_triggers(
	runes: Array[TileCard],
	activation_scales: Array[float] = [],
	source_hex: Hex = null,
) -> void:
	turn_resolver.queue_tile_card_triggers(runes, activation_scales, source_hex)


## Removes tile_card from the map after every trigger queued from source_hex resolves.
func schedule_destroy_after_trigger_link(
	source_hex: Hex,
	tile_card: TileCard,
	on_destroy: Callable = Callable(),
) -> void:
	turn_resolver.schedule_destroy_after_trigger_link(source_hex, tile_card, on_destroy)


## Show floating text at a world position on the current scene.
func create_floating_text(pos: Vector2, text: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	turn_resolver.create_floating_text(pos, text, color, icon)


## Converts map coordinates to local pixel position on the base tile layer.
func map_to_local(coords: Vector2i) -> Vector2i:
	return base_layer.map_to_local(coords)


## True while a hand card is snapping onto a hex and has not committed yet.
func is_card_placement_in_progress() -> bool:
	return card_placement_handler != null and card_placement_handler.is_placement_in_progress()


## Resolves every placed rune in trigger order when the player ends the turn.
func on_turn_ended() -> void:
	await turn_resolver.resolve_turn()


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
		var breakdown := GameManager.get_segment_turn_contribution_breakdown(
			segment_index,
			score,
			multiplier
		)
		segments.append({
			"score": breakdown.display_energy,
			"multiplier": breakdown.display_multiplier,
			"total_score": breakdown.contribution,
			"gold": gold,
		})
		total_score += breakdown.contribution
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
	_event_sealed_coords.clear()
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
		"personal_output_bonus": rune.personal_output_bonus,
		"run_trigger_count": rune.run_trigger_count,
		"is_empowered": rune.is_empowered,
		"potion_fuses": rune.potion_fuses.duplicate(true),
	}
	return data


func _deserialize_placed_tile_card(data: Dictionary) -> TileCard:
	var template := GameManager.get_tile_card_by_id(data.get("rune_id", ""))
	if template == null:
		return null

	var rune := template.duplicate(true)
	rune.activation_count = int(data.get("activation_count", 0))
	rune.is_active = bool(data.get("is_active", true))
	rune.bonus_production_amount = float(data.get("bonus_production_amount", 0.0))
	rune.personal_output_bonus = float(data.get("personal_output_bonus", 0.0))
	rune.run_trigger_count = int(data.get("run_trigger_count", 0))
	rune.is_empowered = bool(data.get("is_empowered", false))
	rune.potion_fuses.clear()
	for fuse in data.get("potion_fuses", []):
		if fuse is Dictionary:
			rune.potion_fuses.append(fuse.duplicate(true))
	return rune

#endregion
