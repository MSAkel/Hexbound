class_name HexHoverUI
extends Node

## Tile inspect panel, occupied-card overlay, and hover process gating for HexTileMap.

const TILE_PANEL_HOVER_DELAY := 0.4

var map: HexTileMap
var _tile_panel_hover_coords: Vector2i = Vector2i(-1, -1)
var _tile_panel_timer: Timer


func setup(tile_map: HexTileMap) -> void:
	map = tile_map
	_tile_panel_timer = Timer.new()
	_tile_panel_timer.one_shot = true
	_tile_panel_timer.wait_time = TILE_PANEL_HOVER_DELAY
	_tile_panel_timer.timeout.connect(_on_tile_panel_hover_timeout)
	add_child(_tile_panel_timer)
	map.tile_panel.hide()
	set_process(false)
	# Named method so EventBus drops this when HoverUI leaves the tree.
	EventBus.card_drag_started.connect(_on_card_drag_started_hide_tile_panel)


func _process(_delta: float) -> void:
	# Re-anchor while visible so zoom or pan mid-hover stays lined up with the tile.
	if map.tile_panel.visible and _tile_panel_hover_coords != Vector2i(-1, -1):
		map.tile_panel.update_anchor(map._get_tile_screen_rect(_tile_panel_hover_coords))


## Start or refresh hover feedback for the tile under the cursor.
func update_tile_panel_hover(map_coords: Vector2i) -> void:
	if not map.is_in_map(map_coords) or not map.is_tile_interactable(map_coords):
		hide_tile_panel()
		return

	var hex: Hex = map.map_data[map_coords]

	# Empty tiles have nothing for the panel. Segment role tints come from selection hover.
	if hex.active_tile_card == null:
		hide_tile_panel()
		return

	if map_coords == _tile_panel_hover_coords:
		if map.tile_panel.visible:
			map.tile_panel.update_anchor(map._get_tile_screen_rect(map_coords))
		return

	_tile_panel_hover_coords = map_coords
	_update_occupied_inspect_overlay(hex)
	map.tile_panel.hide()
	_set_panel_process(false)
	_tile_panel_timer.start()


func hide_tile_panel() -> void:
	_tile_panel_hover_coords = Vector2i(-1, -1)
	_tile_panel_timer.stop()
	map.tile_panel.hide()
	_set_panel_process(false)
	_clear_occupied_inspect_overlay()


func _set_panel_process(enabled: bool) -> void:
	set_process(enabled)


func _on_tile_panel_hover_timeout() -> void:
	if _tile_panel_hover_coords == Vector2i(-1, -1):
		return
	if not map.map_data.has(_tile_panel_hover_coords):
		return
	var hex: Hex = map.map_data[_tile_panel_hover_coords]
	if hex.active_tile_card == null:
		return
	map.tile_panel.set_hex(hex, map._get_tile_screen_rect(_tile_panel_hover_coords))
	_set_panel_process(true)


func _on_card_drag_started_hide_tile_panel(_card: CardUI) -> void:
	hide_tile_panel()


# Light tiles this placed card would affect. Skip the hovered cell, matching placement preview.
func _update_occupied_inspect_overlay(hex: Hex) -> void:
	_clear_occupied_inspect_overlay()
	if hex == null or hex.active_tile_card == null:
		return
	if map.card_placement_handler != null and map.card_placement_handler.is_card_selected:
		return

	var origin := hex.coordinates
	for coords: Vector2i in hex.active_tile_card.get_trigger_preview_coords(hex):
		if not map.is_in_map(coords):
			continue
		if coords == origin:
			continue
		map.rune_highlight_overlay_layer.set_cell(
			coords,
			HexTileMap.RUNE_HIGHLIGHT_SOURCE_ID,
			HexTileMap.OVERLAY_TILE_ATLAS_COORDS
		)
		map._inspect_highlight_coords.append(coords)


func _clear_occupied_inspect_overlay() -> void:
	for coords: Vector2i in map._inspect_highlight_coords:
		if map._rune_highlight_still_needed(coords, false, false, true):
			continue
		map.rune_highlight_overlay_layer.set_cell(coords, -1)
	map._inspect_highlight_coords.clear()
