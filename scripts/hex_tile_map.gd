class_name HexTileMap
extends Node2D

# Live map state: tiles, cards, overlays, and save.
# Geometry lives on HexMapLayout. Seated-card lookups live on HexBoardQuery.

var hover_ui: HexHoverUI
var turn_resolver: HexTurnResolver

@onready var tile_panel: TilePanel = get_node_or_null("../MainUI/TerrainTileUI")
@onready var base_layer: TileMapLayer = $BaseLayer
@onready var trigger_link_overlay: TriggerLinkOverlay = $TriggerLinkOverlay
@onready var selection_overlay_layer: TileMapLayer = $SelectionOverlayLayer
@onready var placement_valid_overlay_layer: TileMapLayer = $PlacementValidOverlayLayer
@onready var card_highlight_overlay_layer: TileMapLayer = $CardHighlightOverlayLayer
@onready var disabled_tile_overlay_layer: TileMapLayer = $DisabledTileOverlayLayer
@onready var fading_sector_overlay_layer: TileMapLayer = $FadingSectorOverlayLayer
# Counted dish-recipe seats. Own layer so gold modulate cannot leak onto other overlays.
var dish_recipe_gold_layer: TileMapLayer
# Meal slot fills, the level 3 padlock, and station type tints. Sits just above BaseLayer.
var station_overlay: StationBoardOverlay
# One badge per station at the right end of its row.
var _station_badges: Array[StationBadge] = []

# Selection and placement-valid overlays share one hover tile on source 0 in hex_tile_map.tscn.
const HOVER_OVERLAY_NORMAL := 0
const OVERLAY_TILE_ATLAS_COORDS := Vector2i(0, 0)
# Valid placement targets for restricted cards such as edge, first, or last segment tiles.
const PLACEMENT_VALID_OVERLAY_SOURCE_ID := HOVER_OVERLAY_NORMAL
const PLACEMENT_VALID_OVERLAY_MODULATE := Color(0.45, 0.88, 1.15, 0.72)
# TileCard trigger preview overlay on CardHighlightOverlayLayer.
const CARD_HIGHLIGHT_SOURCE_ID := 0
# Tile-shaped overlays sit under rune icons.
# CardHighlightOverlayLayer tiles use per-tile z_index 3 in hex_tile_map.tscn so they paint above hex items_grid.
const TILE_OVERLAY_LAYER_Z_INDEX := 0
# Disabled and fading-sector layers each expose a single tile on source 0.
const OVERLAY_TILE_SOURCE_ID := 0

# Extra pixels added to tile_size so adjacent tile visuals do not touch. Negative overlaps neighbouring borders.
@export_range(-16, 64, 1) var hex_tile_gap_x: int = -2
@export_range(0, 64, 1) var hex_tile_gap_y: int = 8

# Square tile art size, drawn by SquareTileTexture. tile_size = this + the X/Y gaps.
const HEX_TEXTURE_SIZE := Vector2i(104, 104)
# Placed rune UI. Square token centered on the cell.
const HEX_RUNE_SIZE := Vector2(112, 112)

# Atlas coords for the single base tile on BaseLayer (source 0)
const BASE_TILE_ATLAS_COORDS := Vector2i(0, 0)

var hovered_cell: Vector2i = Vector2i(-1, -1)
# Controller navigation focus, separate from mouse hover.
var _gamepad_focus_cell: Vector2i = Vector2i(-1, -1)
# Dictionary<Vector2i, Hex>
var map_data: Dictionary = {}
# Ring distances, trigger order, and segment grouping.
var _layout: HexMapLayout
# Indexed seated-card lookups. Rebuilt with the board, occupancy updated on place/remove.
var query: HexBoardQuery
# Nested visual refreshes must not restart a board-chip walk already in progress.
var _refreshing_board_chips: bool = false
# Scene Transform position, kept after generate_terrain recenters the board.
var _scene_position := Vector2.ZERO
var _scene_position_cached := false

# Card placement handler
var card_placement_handler: CardPlacementHandler
# Looked up on first use. Absent in headless playtests.
var _hand: Hand

var _event_highlighted_coords: Array[Vector2i] = []
var _disabled_tile_coords: Array[Vector2i] = []
# Empty tiles locked by the Sealed Hexes event. Shares the disabled overlay layer.
var _event_sealed_coords: Array[Vector2i] = []
# Valid placement target while a hand card is selected.
var _placement_preview_cell: Vector2i = Vector2i(-1, -1)
# Tiles lit when a card credits another segment's turn total.
var _flashed_segment_coords: Array[Vector2i] = []
var _flash_segment_generation: int = 0
## Occupied tiles lit while aiming a tile-target condiment.
var _condiment_target_coords: Array[Vector2i] = []
## Screen-space centers of the staff hexes, one per station. See set_staff_screen_centers().
var _staff_screen_centers: Array[Vector2] = []
## Completed turn snapshots for the current round. Each entry matches capture_segment_turn_snapshot().
var _round_turn_snapshots: Array = []

## Gold wash on a dedicated layer so dish recipe seats do not recolor other rune highlights.
const DISH_RECIPE_GOLD_MODULATE := Color(1.35, 1.05, 0.25, 1.0)
# How long a destination-segment flash stays visible during card activation.
const SEGMENT_CREDIT_FLASH_DURATION := 0.5
## Gap between a station's first spot and its badge, in map pixels.
const STATION_BADGE_GAP := 18.0
## Staff hexes sit this many board columns left of their station's first spot, clear of the badges.
const STAFF_COLUMN_OFFSET := 3.5

# Occupied-tile inspect overlay from get_trigger_preview_coords.
var _inspect_highlight_coords: Array[Vector2i] = []
# Inspect overlay seats currently stamped on dish_recipe_gold_layer.
var _inspect_gold_highlight_coords: Array[Vector2i] = []
# Placement and inspect seats currently stamped on dish_recipe_gold_layer.
var _dish_recipe_gold_coords: Array[Vector2i] = []


func _ready() -> void:
	_layout = HexMapLayout.new()
	_layout.setup(self)
	query = HexBoardQuery.new()
	query.setup(self)
	# Hex fills stay under card icons.
	card_highlight_overlay_layer.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	placement_valid_overlay_layer.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	placement_valid_overlay_layer.modulate = PLACEMENT_VALID_OVERLAY_MODULATE
	_setup_dish_recipe_gold_layer()
	_setup_station_overlay()
	_apply_square_tile_textures()
	_apply_tile_spacing()
	trigger_link_overlay.setup(self)
	generate_terrain()
	EventBus.turn_ended.connect(on_turn_ended)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.condiment_fuses_changed.connect(_refresh_condiment_fuse_badges)
	# Dish chips read the staff recipe discount, so a roster change can move them.
	EventBus.staff_roster_changed.connect(refresh_board_output_chips)
	StaffManager.bind_board(self)
	StationManager.bind_board(self)
	EventBus.station_state_changed.connect(_on_station_state_changed)

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


func _refresh_condiment_fuse_badges() -> void:
	for hex: Hex in get_all_hexes_with_runes():
		if hex.card_icon_ui != null and hex.active_tile_card != null:
			hex.card_icon_ui.refresh_condiment_badges(hex.active_tile_card, hex.coordinates)
	_refresh_map_focus_overlays()
	if hover_ui != null:
		hover_ui.refresh_current_hover()


func _exit_tree() -> void:
	StaffManager.unbind_board(self)
	StationManager.unbind_board(self)
	_free_map_hexes()


## Swap each layer's authored hex PNG for a generated square tile in the same colours.
func _apply_square_tile_textures() -> void:
	var styles := {
		base_layer: SquareTileTexture.BASE,
		selection_overlay_layer: SquareTileTexture.HOVER,
		card_highlight_overlay_layer: SquareTileTexture.CARD_HIGHLIGHT,
		disabled_tile_overlay_layer: SquareTileTexture.DISABLED,
		fading_sector_overlay_layer: SquareTileTexture.FADING_SECTOR,
	}
	for layer: TileMapLayer in styles:
		if layer == null or layer.tile_set == null:
			continue
		var atlas := layer.tile_set.get_source(OVERLAY_TILE_SOURCE_ID) as TileSetAtlasSource
		if atlas != null:
			atlas.texture = SquareTileTexture.get_texture(styles[layer], HEX_TEXTURE_SIZE)


# Widen the grid cells past the tile texture, creating visible gaps.
# Atlas region follows the texture so a single tile still slices as one tile.
func _apply_tile_spacing() -> void:
	var spaced_tile_size := Vector2i(
		HEX_TEXTURE_SIZE.x + hex_tile_gap_x,
		HEX_TEXTURE_SIZE.y + hex_tile_gap_y
	)
	for layer: TileMapLayer in [
		base_layer,
		selection_overlay_layer,
		placement_valid_overlay_layer,
		card_highlight_overlay_layer,
		disabled_tile_overlay_layer,
		fading_sector_overlay_layer,
		dish_recipe_gold_layer,
	]:
		if layer == null or layer.tile_set == null:
			continue
		layer.tile_set.tile_size = spaced_tile_size
		_sync_tileset_atlas_regions(layer.tile_set)


## Slice each atlas as a single tile. Use the texture size when present so mismatched art still works.
func _sync_tileset_atlas_regions(tile_set: TileSet) -> void:
	for i in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(i))
		if source is TileSetAtlasSource:
			var atlas := source as TileSetAtlasSource
			if atlas.texture != null:
				atlas.texture_region_size = Vector2i(atlas.texture.get_size())
			else:
				atlas.texture_region_size = HEX_TEXTURE_SIZE


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_processing_turn:
		dismiss_hover_feedback()
		return

	if event is InputEventMouseMotion:
		if card_placement_handler.is_card_selected:
			# CardPlacementHandler drives tile-panel inspect during placement drag.
			pass
		elif _is_cursor_on_hand_card():
			# A lifted hand card covers the bottom hexes. Do not inspect tiles through it.
			dismiss_hover_feedback()
		else:
			_update_hover_highlight()
			if hover_ui != null:
				hover_ui.update_tile_panel_hover(_mouse_map_coords())


func _is_cursor_on_hand_card() -> bool:
	if not is_instance_valid(_hand):
		_hand = get_tree().get_first_node_in_group("run_hand") as Hand
	return _hand != null and _hand.is_mouse_on_card()


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


## Refreshes tile cards, hover selection, and dashed outlines.
func _refresh_map_focus_overlays() -> void:
	_refresh_tile_card_visibility()
	_refresh_segment_role_highlights()
	refresh_dashed_outlines()


func _refresh_tile_card_visibility() -> void:
	for hex: Hex in get_all_hexes_with_runes():
		hex._apply_display_mode()


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


func _setup_station_overlay() -> void:
	station_overlay = StationBoardOverlay.new()
	station_overlay.name = "StationOverlay"
	station_overlay.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	add_child(station_overlay)
	# Draw over the dashed base hexes and under every overlay layer and seated card.
	move_child(station_overlay, base_layer.get_index() + 1)
	station_overlay.setup(self)


## Redraws Meal slot locks, station tints and badges after a station change.
func refresh_station_visuals() -> void:
	if station_overlay != null:
		station_overlay.refresh()
	_ensure_station_badges()


func _on_station_state_changed(segment_index: int) -> void:
	refresh_station_visuals()
	# A Meal slot can lock or unlock under a seated Meal. Re-dim it.
	for hex: Hex in get_hexes_in_segment(segment_index):
		hex.refresh_own_visuals()
	refresh_board_output_chips()


## Badges sit in one column left of the board, centered on each station row.
func _ensure_station_badges() -> void:
	var segment_count := get_segment_count()
	if segment_count <= 0:
		return
	while _station_badges.size() < segment_count:
		var badge := StationBadge.new()
		badge.name = "StationBadge%d" % _station_badges.size()
		add_child(badge)
		badge.setup(self, _station_badges.size())
		_station_badges.append(badge)
	var left_edge := INF
	for segment_index in segment_count:
		var first := _layout.get_first_tile_coords_in_segment(segment_index)
		left_edge = minf(left_edge, base_layer.map_to_local(first).x)
	for segment_index in segment_count:
		var badge := _station_badges[segment_index]
		var first := _layout.get_first_tile_coords_in_segment(segment_index)
		var center_y := base_layer.position.y + base_layer.map_to_local(first).y
		badge.reset_size()
		var badge_size := badge.get_combined_minimum_size()
		var x := base_layer.position.x + left_edge - HEX_TEXTURE_SIZE.x * 0.5 - STATION_BADGE_GAP - badge_size.x
		badge.position = Vector2(x, center_y - badge_size.y * 0.5)


func _setup_dish_recipe_gold_layer() -> void:
	dish_recipe_gold_layer = TileMapLayer.new()
	dish_recipe_gold_layer.name = "DishRecipeGoldOverlayLayer"
	dish_recipe_gold_layer.tile_set = card_highlight_overlay_layer.tile_set
	dish_recipe_gold_layer.z_index = TILE_OVERLAY_LAYER_Z_INDEX
	dish_recipe_gold_layer.modulate = DISH_RECIPE_GOLD_MODULATE
	add_child(dish_recipe_gold_layer)


## Gold wash on a prefix seat whose card will count toward the dish's plated output.
func stamp_dish_recipe_gold_highlight(coords: Vector2i) -> void:
	if coords in _dish_recipe_gold_coords:
		return
	_dish_recipe_gold_coords.append(coords)
	dish_recipe_gold_layer.set_cell(
		coords,
		CARD_HIGHLIGHT_SOURCE_ID,
		OVERLAY_TILE_ATLAS_COORDS
	)


func clear_dish_recipe_gold_highlights_at(coords_list: Array[Vector2i]) -> void:
	for coords: Vector2i in coords_list:
		_dish_recipe_gold_coords.erase(coords)
		dish_recipe_gold_layer.set_cell(coords, -1)


func _refresh_rune_highlight_modulate() -> void:
	if not _condiment_target_coords.is_empty():
		card_highlight_overlay_layer.modulate = Color(0.55, 1.15, 0.85, 1.0)
		return
	card_highlight_overlay_layer.modulate = Color.WHITE


func _get_map_focus_cell() -> Vector2i:
	if _placement_preview_cell != Vector2i(-1, -1):
		return _placement_preview_cell
	if InputManager.is_using_gamepad() and _gamepad_focus_cell != Vector2i(-1, -1):
		return _gamepad_focus_cell
	return hovered_cell


func get_gamepad_focus_cell() -> Vector2i:
	return _gamepad_focus_cell


func get_default_gamepad_focus_cell() -> Vector2i:
	if _layout != null:
		return _layout.get_hex_center()
	return Vector2i.ZERO


func ensure_gamepad_focus() -> void:
	if _gamepad_focus_cell != Vector2i(-1, -1) and is_tile_interactable(_gamepad_focus_cell):
		_refresh_map_focus_overlays()
		return
	set_gamepad_focus_cell(get_default_gamepad_focus_cell())


func set_gamepad_focus_cell(coords: Vector2i) -> void:
	if not is_tile_interactable(coords):
		return
	if _gamepad_focus_cell == coords:
		return
	_gamepad_focus_cell = coords
	_refresh_map_focus_overlays()
	if hover_ui != null and InputManager.is_using_gamepad():
		inspect_gamepad_focus_tile()


func clear_gamepad_focus() -> void:
	if _gamepad_focus_cell == Vector2i(-1, -1):
		return
	_gamepad_focus_cell = Vector2i(-1, -1)
	_refresh_map_focus_overlays()
	if hover_ui != null:
		hover_ui.hide_tile_panel()


## Moves controller focus. Horizontal input wraps across row ends onto the next row.
## Vertical input keeps the same board column lane across rows.
func move_gamepad_focus(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	ensure_gamepad_focus()
	var rows: Array = _layout.get_spatial_rows()
	if rows.is_empty():
		return
	if absf(direction.x) > absf(direction.y):
		_move_gamepad_focus_horizontal(int(signf(direction.x)), rows)
		return
	_move_gamepad_focus_vertical(int(signf(direction.y)), rows)


func inspect_gamepad_focus_tile() -> void:
	if hover_ui == null:
		return
	var coords := _gamepad_focus_cell
	if not is_tile_interactable(coords):
		hover_ui.hide_tile_panel()
		return
	var hex: Hex = map_data.get(coords)
	if hex == null or hex.active_tile_card == null:
		hover_ui.hide_tile_panel()
		return
	hover_ui.update_tile_panel_hover(coords, true)


func _find_gamepad_row_col(rows: Array) -> Vector2i:
	for r in rows.size():
		var col: int = rows[r].find(_gamepad_focus_cell)
		if col >= 0:
			return Vector2i(r, col)
	return Vector2i(-1, -1)


## Negative lanes are counted from the right (-1 rightmost, -2 second from right).
## Non-negative lanes are left-based indices (0 leftmost, 1 second from left).
func _get_gamepad_vertical_lane(col_index: int, row_size: int) -> int:
	if col_index <= 0:
		return 0
	if row_size > 2 and col_index == 1:
		return 1
	if col_index >= row_size - 1:
		return -1
	if row_size > 2 and col_index == row_size - 2:
		return -2
	return col_index


func _gamepad_lane_to_col_index(lane: int, row_size: int) -> int:
	if row_size <= 0:
		return -1
	if lane < 0:
		return clampi(row_size + lane, 0, row_size - 1)
	return clampi(lane, 0, row_size - 1)


func _try_set_gamepad_focus_from_row(row: Array, col_index: int) -> void:
	if col_index < 0 or col_index >= row.size():
		return
	var coords: Vector2i = row[col_index]
	if is_tile_interactable(coords):
		set_gamepad_focus_cell(coords)


func _move_gamepad_focus_horizontal(step: int, rows: Array) -> void:
	var row_col := _find_gamepad_row_col(rows)
	if row_col.x < 0:
		return
	var new_row := row_col.x
	var new_col := row_col.y + step
	if new_col >= rows[row_col.x].size():
		new_row += 1
		new_col = 0
	elif new_col < 0:
		new_row -= 1
		if new_row < 0:
			return
		new_col = rows[new_row].size() - 1
	if new_row < 0 or new_row >= rows.size():
		return
	_try_set_gamepad_focus_from_row(rows[new_row], clampi(new_col, 0, rows[new_row].size() - 1))


func _move_gamepad_focus_vertical(step: int, rows: Array) -> void:
	var row_col := _find_gamepad_row_col(rows)
	if row_col.x < 0:
		return
	var new_row := row_col.x + step
	if new_row < 0 or new_row >= rows.size():
		return
	var lane := _get_gamepad_vertical_lane(row_col.y, rows[row_col.x].size())
	_try_set_gamepad_focus_from_row(rows[new_row], _gamepad_lane_to_col_index(lane, rows[new_row].size()))


func _refresh_segment_role_highlights() -> void:
	selection_overlay_layer.clear()

	var focus_cell := _get_map_focus_cell()
	if focus_cell != Vector2i(-1, -1):
		_stamp_hover_selection(focus_cell)


func _stamp_hover_selection(coords: Vector2i) -> void:
	selection_overlay_layer.set_cell(
		coords,
		HOVER_OVERLAY_NORMAL,
		OVERLAY_TILE_ATLAS_COORDS
	)


## Hides the dashed hex outline during the full order overlay, or when a card occupies the tile.
func refresh_dashed_outlines() -> void:
	for coords: Vector2i in map_data:
		if _should_hide_dashed_outline(coords):
			base_layer.set_cell(coords, -1)
		else:
			base_layer.set_cell(coords, 0, BASE_TILE_ATLAS_COORDS)


## Recompute output chips that read other placed cards. Dishes, steak-style ingredients, and similar.
func refresh_board_output_chips() -> void:
	if _refreshing_board_chips:
		return
	_refreshing_board_chips = true
	for hex: Hex in get_all_hexes_with_runes():
		if hex.active_tile_card == null or hex.card_icon_ui == null:
			continue
		hex.card_icon_ui.refresh_output_chip(hex.active_tile_card)
	_refreshing_board_chips = false


## Kept for older call sites. Refreshes every context-sensitive board chip, not just dishes.
func refresh_dish_output_chips() -> void:
	refresh_board_output_chips()


func _should_hide_dashed_outline(coords: Vector2i) -> bool:
	var hex: Hex = map_data[coords]
	return hex.active_tile_card != null


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


## Outer ring tiles have at least one hex neighbor direction that leaves the map.
func is_edge_tile(coords: Vector2i) -> bool:
	if query == null:
		return false
	return query.is_edge_tile(coords)


## Every seated card currently on the map.
## rune_type: TileCardType, or TileCard.PRODUCER_TYPE_FILTER for seated Ingredients.
func get_all_placed_tile_cards(rune_type: Variant = null) -> Array[TileCard]:
	if query == null:
		return []
	return query.placed_cards(rune_type)


## True when a placed rune can fire during its own trigger-order slot this turn.
## A Meal left in a station's second slot after the station drops below level 3 sits idle.
func is_tile_card_active(hex: Hex) -> bool:
	if hex == null or hex.active_tile_card == null:
		return false
	if hex.is_disabled_by_difficulty:
		return false
	if StationManager.is_meal_slot_locked(hex.coordinates):
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


## Hex tiles that currently hold a card.
func get_all_hexes_with_runes() -> Array[Hex]:
	if query == null:
		return []
	return query.occupied_hexes()


func _place_hex_tile(offset: Vector2i) -> void:
	var h := Hex.new(offset)
	h.setup(self)
	map_data[offset] = h
	base_layer.set_cell(offset, 0, BASE_TILE_ATLAS_COORDS)


## Builds the shared kitchen board: four stations of eight hexes.
func generate_terrain() -> void:
	_free_map_hexes()
	base_layer.clear()
	selection_overlay_layer.clear()
	placement_valid_overlay_layer.clear()
	hovered_cell = Vector2i(-1, -1)
	_placement_preview_cell = Vector2i(-1, -1)
	_gamepad_focus_cell = Vector2i(-1, -1)
	card_highlight_overlay_layer.clear()
	if dish_recipe_gold_layer != null:
		dish_recipe_gold_layer.clear()
	_dish_recipe_gold_coords.clear()
	_inspect_gold_highlight_coords.clear()
	disabled_tile_overlay_layer.clear()
	fading_sector_overlay_layer.clear()
	_disabled_tile_coords.clear()
	card_highlight_overlay_layer.modulate = Color.WHITE

	var cells := HexMapLayout.compute_board_cells(base_layer)
	for coords: Vector2i in cells:
		_place_hex_tile(coords)

	var hex_center := HexMapLayout.board_hex_center(cells)
	_layout.reset(hex_center)
	if query != null:
		query.rebuild_spatial_index()
	if map_data.size() != HexMapLayout.BOARD_TILE_COUNT:
		push_warning("HexTileMap: expected %d kitchen tiles, got %d." % [HexMapLayout.BOARD_TILE_COUNT, map_data.size()])
	_layout.reset_turn_results()
	_center_map_on_origin()
	refresh_station_visuals()


## Frees Hex UI Controls and drops dict refs so Nodes/RefCounted tiles cannot pile up.
func _free_map_hexes() -> void:
	for hex: Hex in map_data.values():
		if hex != null:
			hex.dispose()
	map_data.clear()
	# map_data.clear() does not touch layout or query caches. Stale coords would crash turn resolution.
	if query != null:
		query.clear()
	if _layout != null:
		_layout.invalidate_caches()


## Occupancy changed on a live hex. Keeps HexBoardQuery's card-to-hex index current and
## re-checks station types once the edit settles (a card leaving can cost a station its type).
func notify_tile_card_occupancy_changed(hex: Hex, previous: TileCard, current: TileCard) -> void:
	if query != null:
		query.set_occupancy(hex, previous, current)
	StationManager.queue_type_evaluation()


## Apply difficulty-driven map randomization after run RNG setup rolls.
func apply_run_start_randomization() -> void:
	if RunSaveManager.should_restore_run():
		return
	_apply_difficulty_disabled_tiles()


# Randomly disable tiles for higher difficulty. Meal slots are never disabled.
func _apply_difficulty_disabled_tiles() -> void:
	var disable_count := Difficulty.get_disabled_tile_count(GameManager.selected_difficulty)
	if disable_count <= 0:
		return

	var candidates: Array[Vector2i] = []
	for coords: Vector2i in map_data:
		if is_meal_slot(coords):
			continue
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


## Tile 180 degrees from coords around the map center.
func get_opposite_coords(coords: Vector2i) -> Vector2i:
	return _layout.get_opposite_coords(coords)


## All map coordinates sorted by the active trigger-order rule.
func get_coords_in_trigger_order() -> Array[Vector2i]:
	return _layout.get_coords_in_trigger_order()


## All map hex tiles in trigger order.
func get_hexes_in_trigger_order() -> Array[Hex]:
	if query == null:
		return []
	return query.hexes_in_trigger_order()


## Station (row) index for a tile, or -1 when the tile is not on the board.
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


## Cards on a station's regular (non-Meal) spots. Station types and Meal requirements read these.
func get_regular_spot_cards(segment_index: int) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for hex: Hex in get_hexes_in_segment(segment_index):
		if hex.active_tile_card != null and not is_meal_slot(hex.coordinates):
			cards.append(hex.active_tile_card)
	return cards


## True for the Meal-only seats at the end of each station.
func is_meal_slot(coords: Vector2i) -> bool:
	return _layout.is_meal_slot(coords)


## 0 or 1 for Meal slots, -1 for regular seats.
func get_meal_slot_index(coords: Vector2i) -> int:
	return _layout.get_meal_slot_index(coords)


func get_meal_slot_coords(segment_index: int) -> Array[Vector2i]:
	return _layout.get_meal_slot_coords(segment_index)


## Tile count for a segment index, or 0 when the index is invalid.
func get_segment_size(segment_index: int) -> int:
	return _layout.get_segment_size(segment_index)


func build_segments() -> Array[Array]:
	return _layout.build_segments()


func mark_segment_resolved(segment_index: int) -> bool:
	if not _layout.mark_segment_resolved(segment_index):
		return false
	EventBus.segment_resolved.emit(segment_index)
	return true


func is_segment_resolved(segment_index: int) -> bool:
	return _layout.is_segment_resolved(segment_index)


func mark_segment_received_relay(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= get_segment_count():
		return
	_layout.mark_segment_received_relay(segment_index)
	RunLedger.record_pass_relay(segment_index)


func count_segments_that_received_relay() -> int:
	return _layout.count_segments_that_received_relay()


func get_segment_breaks(segment_index: int) -> int:
	return _layout.get_segment_breaks(segment_index)


## Records a break on the card's segment for the Hour results.
func notify_card_broke(tile_card: TileCard) -> void:
	var hex := get_hex_for_tile_card(tile_card)
	if hex == null:
		return
	_layout.add_segment_break(get_segment_index(hex.coordinates))


## Number of chef-specific segments on the current map.
func get_segment_count() -> int:
	return _layout.build_segments().size()


## All hex tiles belonging to one segment index.
func get_hexes_in_segment(segment_index: int) -> Array[Hex]:
	if query == null:
		return []
	return query.hexes_in_segment(segment_index)


## Clears per-segment turn totals at the start of turn resolution.
func reset_hour_results() -> void:
	_layout.reset_turn_results()
	EventBus.hour_results_reset.emit()


## Records Flavour produced by a card on its spot's segment.
func add_turn_flavour_for_tile(tile: Hex, amount: int) -> void:
	add_turn_flavour_for_segment(get_segment_index(tile.coordinates), amount)


## Records Flavour on a segment by index. Used when a card credits another segment.
func add_turn_flavour_for_segment(segment_index: int, amount: int) -> void:
	if amount == 0:
		return

	_layout.add_segment_turn_flavour(segment_index, amount)
	_emit_hour_results_changed(segment_index)


## Records additive mult produced by a rune on its tile's segment.
func add_turn_additive_mult_for_tile(tile: Hex, amount: float) -> void:
	add_turn_additive_mult_for_segment(get_segment_index(tile.coordinates), amount)


## Records additive mult on a segment by index. Used when a card credits another segment.
func add_turn_additive_mult_for_segment(segment_index: int, amount: float) -> void:
	if is_zero_approx(amount):
		return

	_layout.add_segment_additive_mult(segment_index, amount)
	_emit_hour_results_changed(segment_index)


## Records multiplicative mult produced by a rune on its tile's segment.
func multiply_turn_multiplicative_mult_for_tile(tile: Hex, factor: float) -> void:
	multiply_turn_multiplicative_mult_for_segment(get_segment_index(tile.coordinates), factor)


## Records multiplicative mult on a segment by index. Used when a card credits another segment.
func multiply_turn_multiplicative_mult_for_segment(segment_index: int, factor: float) -> void:
	if is_zero_approx(factor):
		return

	_layout.multiply_segment_multiplicative_mult(segment_index, factor)
	_emit_hour_results_changed(segment_index)


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
	_emit_hour_results_changed(segment_index)


## Records gold on a segment by index. Used when a drink relays gold to the next segment.
func add_turn_gold_for_segment(segment_index: int, amount: int) -> void:
	if amount == 0:
		return
	if not EventManager.can_gain_gold():
		return
	_layout.add_segment_turn_gold(segment_index, amount)
	GoldManager.add(amount)
	_emit_hour_results_changed(segment_index)


## Notifies UI of the latest hour Flavour, Mult, and Gold.
func _emit_hour_results_changed(segment_index: int) -> void:
	EventBus.hour_results_changed.emit(
		segment_index,
		_layout.get_hour_flavour(),
		_layout.get_hour_additive_mult(),
		_layout.get_hour_gold()
	)


## Hour Rating is Flavour x Additive. xMult already folded into Additive as cards fire.
func _apply_segment_turn_totals_to_game_manager() -> void:
	var flavour := get_hour_flavour()
	var additive_mult := get_hour_additive_mult()
	var contribution := GameManager.compute_hour_turn_contribution(flavour, additive_mult)
	var contributions: Array[int] = [contribution]
	GameManager.record_turn_segment_peaks(contributions)
	GameManager.turn_score = contribution


func get_segment_turn_flavour(segment_index: int) -> int:
	return _layout.get_segment_turn_flavour(segment_index)


func get_segment_additive_mult(segment_index: int) -> float:
	return _layout.get_segment_additive_mult(segment_index)


func get_segment_multiplicative_mult(segment_index: int) -> float:
	return _layout.get_segment_multiplicative_mult(segment_index)

func get_segment_turn_gold(segment_index: int) -> int:
	return _layout.get_segment_turn_gold(segment_index)


func get_hour_flavour() -> int:
	if _layout == null:
		return 0
	return _layout.get_hour_flavour()


func get_hour_additive_mult() -> float:
	if _layout == null:
		return 1.0
	return _layout.get_hour_additive_mult()


func get_hour_gold() -> int:
	if _layout == null:
		return 0
	return _layout.get_hour_gold()


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
		fading_sector_overlay_layer.set_cell(coords, -1)
	_event_highlighted_coords.clear()


## Briefly lights a segment so the player can see where forwarded Energy or Mult landed.
func flash_segment_highlight(segment_index: int) -> void:
	_clear_flashed_segment_highlight()
	if segment_index < 0:
		return

	for hex: Hex in get_hexes_in_segment(segment_index):
		var coords := hex.coordinates
		card_highlight_overlay_layer.set_cell(
			coords,
			CARD_HIGHLIGHT_SOURCE_ID,
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
		if _rune_highlight_still_needed(coords, true):
			continue
		card_highlight_overlay_layer.set_cell(coords, -1)
	_flashed_segment_coords.clear()


## Lights occupied tiles while a tile-target condiment is being aimed.
func set_condiment_target_highlights(coords: Array[Vector2i]) -> void:
	clear_condiment_target_highlights()
	_condiment_target_coords = coords.duplicate()
	card_highlight_overlay_layer.modulate = Color(0.55, 1.15, 0.85, 1.0)
	for cell in _condiment_target_coords:
		card_highlight_overlay_layer.set_cell(
			cell,
			OVERLAY_TILE_SOURCE_ID,
			OVERLAY_TILE_ATLAS_COORDS
		)


func clear_condiment_target_highlights() -> void:
	var previous := _condiment_target_coords.duplicate()
	_condiment_target_coords.clear()
	for cell in previous:
		if _rune_highlight_still_needed(cell, false):
			continue
		card_highlight_overlay_layer.set_cell(cell, -1)
	_refresh_rune_highlight_modulate()


## True while placement preview, a credit flash, inspect, or condiment aim still owns this overlay cell.
func _rune_highlight_still_needed(
	coords: Vector2i,
	from_flash: bool,
	from_inspect: bool = false
) -> bool:
	if card_placement_handler != null and card_placement_handler.is_highlighting_coord(coords):
		return true
	if not from_flash and coords in _flashed_segment_coords:
		return true
	if not from_inspect and coords in _inspect_highlight_coords:
		return true
	if coords in _condiment_target_coords:
		return true
	return false


## True while a credit flash, inspect, or condiment aim is lighting this tile.
func has_hovered_segment_highlight_at(coords: Vector2i) -> bool:
	return (
		coords in _flashed_segment_coords
		or coords in _inspect_highlight_coords
		or coords in _condiment_target_coords
	)


func _get_hex_trigger_order_index(current_tile: Hex) -> int:
	if query == null:
		return -1
	return query.trigger_index(current_tile)


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


## Returns the hex tile that currently holds the card, or null when it is not placed.
func get_hex_for_tile_card(rune: TileCard) -> Hex:
	if query == null:
		return null
	return query.get_hex_for_card(rune)


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


#region Staff column anchors

## Screen rect of the staff slot for a station: same size as a spot, on the station's row.
## Empty when the row is missing.
func get_staff_slot_screen_rect(segment_index: int) -> Rect2:
	var first := _layout.get_first_tile_coords_in_segment(segment_index)
	if first == Vector2i(-1, -1) or not is_inside_tree():
		return Rect2()
	var column_width := float(base_layer.tile_set.tile_size.x)
	var center_local := base_layer.map_to_local(first) - Vector2(column_width * STAFF_COLUMN_OFFSET, 0.0)
	var canvas_xform: Transform2D = base_layer.get_global_transform_with_canvas()
	var screen_size: Vector2 = canvas_xform.basis_xform(Vector2(HEX_TEXTURE_SIZE)).abs()
	return Rect2(canvas_xform * center_local - screen_size * 0.5, screen_size)


## Screen positions of the staff hexes, pushed by the staff column UI. Empty on headless boards.
func set_staff_screen_centers(centers: Array[Vector2]) -> void:
	_staff_screen_centers = centers


## Map-local center of the staff hex linked to a station. The column is fixed on screen,
## so its position is converted back through the camera. Headless boards have no column
## and fall back to the row's first spot.
func get_staff_anchor_local(segment_index: int) -> Vector2:
	if segment_index >= 0 and segment_index < _staff_screen_centers.size() and is_inside_tree():
		var canvas_xform: Transform2D = base_layer.get_global_transform_with_canvas()
		return canvas_xform.affine_inverse() * _staff_screen_centers[segment_index]
	var rows: Array = _layout.get_spatial_rows()
	if segment_index < 0 or segment_index >= rows.size() or rows[segment_index].is_empty():
		return Vector2.ZERO
	return base_layer.map_to_local(rows[segment_index][0])


## Scene-global center of a staff hex, for floating text.
func get_staff_anchor_global(segment_index: int) -> Vector2:
	return to_global(get_staff_anchor_local(segment_index))


## Bolt from a staff hex to the spot its effect just reached.
func play_staff_bolt(segment_index: int, target: Hex) -> void:
	if target == null or GameManager.skip_presentation:
		return
	trigger_link_overlay.play_bolt_between(
		get_staff_anchor_local(segment_index),
		base_layer.map_to_local(target.coordinates)
	)

#endregion


## Scene-global center of a hex tile. Callers convert this to screen space for CanvasLayer floats.
func floating_text_position_for_hex(coords: Vector2i) -> Vector2:
	return to_global(base_layer.map_to_local(coords))


## World-space center of the generated hexes.
func get_map_world_center() -> Vector2:
	if map_data.is_empty():
		return global_position
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var half := Vector2(HEX_TEXTURE_SIZE) * 0.5
	for coords: Vector2i in map_data.keys():
		var center := to_global(base_layer.map_to_local(coords))
		min_p = min_p.min(center - half)
		max_p = max_p.max(center + half)
	return (min_p + max_p) * 0.5


## Keep the board centered on world origin so a camera at (0, 0) frames it.
## Extra shift comes from this node's scene position.
func _center_map_on_origin() -> void:
	if not _scene_position_cached:
		_scene_position = position
		_scene_position_cached = true
	position = Vector2.ZERO
	global_position -= get_map_world_center()
	position += _scene_position


## Show floating text at a scene-global position on the current scene.
func create_floating_text(
	pos: Vector2,
	text: String,
	color: Color = Color.WHITE,
	icon: Texture2D = null,
	target_icon: Texture2D = null,
	garnished: bool = false
) -> void:
	turn_resolver.create_floating_text(pos, text, color, icon, target_icon, garnished)


## True while a hand card is snapping onto a hex and has not committed yet.
func is_card_placement_in_progress() -> bool:
	return card_placement_handler != null and card_placement_handler.is_placement_in_progress()


## Resolves every placed rune in trigger order when the player ends the turn.
func on_turn_ended() -> void:
	await turn_resolver.resolve_turn()


#region Run save / load

func capture_map_state() -> Dictionary:
	var disabled_coords: Array = []
	for coords: Vector2i in _disabled_tile_coords:
		disabled_coords.append([coords.x, coords.y])

	var placed_spot_cards: Array = []
	for coords: Vector2i in map_data:
		var hex: Hex = map_data[coords]
		if hex.active_tile_card == null:
			continue
		var entry := _serialize_placed_tile_card(hex.active_tile_card)
		entry["coords"] = [coords.x, coords.y]
		placed_spot_cards.append(entry)

	return {
		"disabled_coords": disabled_coords,
		"placed_spot_cards": placed_spot_cards,
		"segment_turn_results": _layout.capture_turn_results(),
		"turn_snapshots": _round_turn_snapshots.duplicate(true),
	}


func restore_map_state(state: Dictionary) -> void:
	_restore_disabled_tiles(state.get("disabled_coords", []))

	for entry: Dictionary in state.get("placed_spot_cards", []):
		var coords_data: Array = entry.get("coords", [])
		if coords_data.size() < 2:
			continue
		var coords := Vector2i(int(coords_data[0]), int(coords_data[1]))
		if not map_data.has(coords):
			continue

		var tile_card := _deserialize_placed_tile_card(entry)
		if tile_card == null:
			continue
		map_data[coords].restore_placed_tile_card(tile_card)

	_layout.apply_turn_results(state.get("segment_turn_results", {}))
	_restore_turn_snapshots(state.get("turn_snapshots", []))


func refresh_hour_results_ui() -> void:
	_emit_hour_results_changed(0)


## Packages hour totals for the per-round turn history (kept in saves).
func capture_segment_turn_snapshot() -> Dictionary:
	var flavour := get_hour_flavour()
	var additive_mult := get_hour_additive_mult()
	var gold := get_hour_gold()
	var rating := GameManager.compute_hour_turn_contribution(flavour, additive_mult)
	return {
		"segments": [{
			"flavour": flavour,
			"additive_mult": additive_mult,
			"multiplicative_mult": 1.0,
			"rating": rating,
			"gold": gold,
		}],
		"total_rating": rating,
		"total_gold": gold,
	}


func _emit_segment_turn_completed_snapshot() -> void:
	var snapshot := capture_segment_turn_snapshot()
	_round_turn_snapshots.append(snapshot)
	EventBus.segment_turn_completed.emit(GameManager.get_turn_number(), snapshot)


func _on_round_changed(_new_round: int) -> void:
	if RunSaveManager.is_restoring():
		return
	_round_turn_snapshots.clear()


func _restore_turn_snapshots(raw_snapshots: Array) -> void:
	_round_turn_snapshots.clear()
	for entry: Variant in raw_snapshots:
		if entry is Dictionary:
			_round_turn_snapshots.append(entry)


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


func _serialize_placed_tile_card(tile_card: TileCard) -> Dictionary:
	var data := {
		"card_id": tile_card.id,
		"activation_count": tile_card.activation_count,
		"is_active": EventManager.get_saved_is_active(tile_card),
		"bonus_production_amount": tile_card.bonus_production_amount,
		"run_trigger_count": tile_card.run_trigger_count,
		"garnish_stacks": tile_card.garnish_stacks,
		"condiment_fuses": tile_card.condiment_fuses.duplicate(true),
	}
	var card_state := tile_card.capture_placed_save_state()
	if not card_state.is_empty():
		data["card_state"] = card_state
	return data


func _deserialize_placed_tile_card(data: Dictionary) -> TileCard:
	var template := GameManager.get_tile_card_by_id(data.get("card_id", ""))
	if template == null:
		return null

	var tile_card := template.duplicate(true)
	tile_card.activation_count = int(data.get("activation_count", 0))
	tile_card.is_active = bool(data.get("is_active", true))
	tile_card.bonus_production_amount = float(data.get("bonus_production_amount", 0.0))
	tile_card.run_trigger_count = int(data.get("run_trigger_count", 0))
	tile_card.garnish_stacks = int(data.get("garnish_stacks", 0))
	tile_card.condiment_fuses.clear()
	for fuse in data.get("condiment_fuses", []):
		if fuse is Dictionary:
			tile_card.condiment_fuses.append(fuse.duplicate(true))
	var card_state: Variant = data.get("card_state", {})
	if card_state is Dictionary and not card_state.is_empty():
		tile_card.apply_placed_save_state(card_state)
	return tile_card

#endregion
