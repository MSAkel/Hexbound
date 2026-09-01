# Handles hand card selection and placement on the hex tile map.
class_name CardPlacementHandler
extends Node


# Reference to the tile map.
var tile_map: HexTileMap

# True while a hand card is selected for placement.
var is_card_selected: bool = false
# True while a drop is snapping in and play_on has not committed yet.
var _is_placing := false

var selected_card: CardUI = null
var _rune_preview: RuneUI
# Faded copy snapped to the hex the dragged rune would land on.
var _tile_landing_preview: RuneUI
# Prevents deselect cleanup when swapping from one selected card to another.
var _switching_selection: bool = false
# Tiles temporarily marked invalid while placing a restricted rune card.
var _restricted_invalid_coords: Array[Vector2i] = []
# Tiles currently showing trigger-effect preview highlights.
var _effect_preview_coords: Array[Vector2i] = []
# Valid placement tiles highlighted for first, last, or edge restrictions.
var _valid_restriction_coords: Array[Vector2i] = []
# Occupied hexes already chosen for a multi-target utility such as Transposition.
var _utility_target_hexes: Array[Hex] = []
var _utility_target_coords: Array[Vector2i] = []
# True until the mouse-up that belongs to the drag that selected the card.
var _awaiting_pointer_release: bool = false
# Screen position of that selecting press, used to tell a click from a drag.
var _select_press_position := Vector2.ZERO
# Ghost stays on the cursor until a successful drop snaps it into the hex.
var _ghost_follow_mouse := false
var _ghost_float_time := 0.0

const VALID_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.7)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.35, 0.35, 0.45)
const RUNE_UI_SCENE: PackedScene = preload("res://scenes/ui/runes/rune_ui.tscn")
# Pointer travel from the selecting press before a release is treated as a drop.
const DRAG_PLACE_THRESHOLD_PX := 8.0
# Bob height in pixels. Raise for more float, lower toward 0 to calm it.
const GHOST_FLOAT_AMPLITUDE := 2.0
# Cycles per second. Raise to bob faster, lower to bob slower.
const GHOST_FLOAT_HZ := 0.85
# Extra scale swing around 1. Set to 0 to disable the pulse.
const GHOST_FLOAT_SCALE_PULSE := 0.006
# Glide duration on release. Keep this short so the drop reads as a fall, not a float.
const GHOST_SNAP_DURATION := 0.10
# Vertical lift while dragging. Negative Y floats the ghost above the board.
const GHOST_LIFT_OFFSET := -16.0
# Above trigger-order numbers (25) and path traces (22) on the map.
const DRAGGED_RUNE_Z_INDEX := 40
const TILE_LANDING_PREVIEW_Z_INDEX := 6
const TILE_LANDING_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.4)


## True while a drop is animating in. The card is not yet committed to the map.
func is_placement_in_progress() -> bool:
	return _is_placing


func _ready() -> void:
	EventBus.card_drag_started.connect(_on_card_selected)
	EventBus.card_drag_ended.connect(_on_card_deselected)
	_setup_rune_preview()


func _setup_rune_preview() -> void:
	_rune_preview = _make_ghost_rune(DRAGGED_RUNE_Z_INDEX)
	_tile_landing_preview = _make_ghost_rune(TILE_LANDING_PREVIEW_Z_INDEX)


func _make_ghost_rune(z: int) -> RuneUI:
	var ghost := RUNE_UI_SCENE.instantiate() as RuneUI
	ghost.visible = false
	ghost.z_index = z
	ghost.custom_minimum_size = HexTileMap.HEX_RUNE_SIZE
	ghost.size = HexTileMap.HEX_RUNE_SIZE
	ghost.pivot_offset = HexTileMap.HEX_RUNE_SIZE / 2.0
	tile_map.add_child(ghost)
	ghost.prepare_placement_ghost()
	return ghost


func _process(delta: float) -> void:
	if not _ghost_follow_mouse or not is_card_selected:
		return
	_ghost_float_time += delta
	_place_rune_preview_at_mouse()


func _input(event: InputEvent) -> void:
	if not is_card_selected or _is_placing:
		return

	# The selecting Control keeps mouse focus, so _unhandled_input never sees this drag.
	if event is InputEventMouseMotion:
		_update_rune_preview()
		return

	if not (event is InputEventMouseButton and not event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _awaiting_pointer_release:
		return

	_awaiting_pointer_release = false
	# A press-and-release on the card, or a tiny drag, is not a drop.
	if selected_card != null and selected_card.is_mouse_over_visual():
		_deselect_card()
		return
	if not _has_dragged_from_select():
		_deselect_card()
		return

	_try_place_card()
	# Leave this mouse-up unhandled. The card Control that took the press must
	# still see the release, or Viewport keeps GUI mouse focus on the hand card
	# and map hover, tooltips, and highlights stop receiving motion.


func _unhandled_input(event: InputEvent) -> void:
	if not is_card_selected or _is_placing:
		return
	
	if event is InputEventMouseMotion:
		_update_rune_preview()
	
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_deselect_card()
			get_viewport().set_input_as_handled()
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_card()
			get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_cancel"):
		_deselect_card()
		get_viewport().set_input_as_handled()


func _on_card_selected(card: CardUI) -> void:
	if selected_card != null and selected_card != card:
		_switching_selection = true
		selected_card.card_state_machine.transition_to_state(CardState.State.BASE)
		_switching_selection = false
		_utility_target_hexes.clear()
		_utility_target_coords.clear()
	
	is_card_selected = true
	selected_card = card
	# The card is selected on mouse-down. A later mouse-up over a hex should place it.
	_awaiting_pointer_release = true
	_select_press_position = tile_map.get_global_mouse_position()
	_ghost_float_time = 0.0
	_ghost_follow_mouse = true
	_update_preview_texture()
	_update_placement_overlays()
	_update_rune_preview()


func _on_card_deselected() -> void:
	if _switching_selection:
		return
	_clear_preview()
	_reset_state()


func _deselect_card() -> void:
	if selected_card and selected_card.card_state_machine:
		selected_card.card_state_machine.transition_to_state(CardState.State.BASE)


func _update_preview_texture() -> void:
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return
	_rune_preview.prepare_placement_ghost()
	_rune_preview.setup(tile_card)
	_rune_preview.hide_output_chip()
	_tile_landing_preview.prepare_placement_ghost()
	_tile_landing_preview.setup(tile_card)


func _update_rune_preview() -> void:
	if selected_card == null or _is_placing:
		return

	var map_coords := _get_mouse_map_coords()
	var hex: Hex = tile_map.map_data.get(map_coords) if tile_map.is_in_map(map_coords) else null
	var over_valid_tile := hex != null \
		and tile_map.is_tile_interactable(map_coords) \
		and _can_place_on_hex(hex)
	var mouse_over_card := selected_card.is_mouse_over_visual()

	# Dip once the cursor leaves the selected card, not only when a tile is targeted.
	selected_card.set_map_tile_hover_active(not mouse_over_card)

	if mouse_over_card:
		selected_card.update_placement_morph_from_cursor()
	else:
		selected_card.complete_placement_morph()

	_show_cursor_rune_preview(selected_card.get_placement_morph_progress())

	if over_valid_tile:
		# Keep the dragged icon on the cursor. A faded copy marks the drop tile.
		tile_map.set_placement_preview_cell(map_coords)
		_show_tile_landing_preview(hex)
		_update_hover_highlights(hex)
	else:
		_hide_tile_landing_preview()
		_rune_preview.hide_output_chip()
		tile_map.clear_placement_preview()
		_clear_hover_highlights()
		_restamp_utility_target_highlights()

	_update_placed_card_tile_panel(map_coords, mouse_over_card)


func _get_mouse_map_coords() -> Vector2i:
	return tile_map.base_layer.local_to_map(
		tile_map.to_local(tile_map.get_global_mouse_position())
	)


# Occupied tiles under the cursor show the placed card inspect panel while dragging to place.
func _update_placed_card_tile_panel(map_coords: Vector2i, mouse_over_card: bool) -> void:
	if tile_map.hover_ui == null:
		return
	if mouse_over_card:
		tile_map.hover_ui.hide_tile_panel()
		return
	if not tile_map.is_in_map(map_coords) or not tile_map.is_tile_interactable(map_coords):
		tile_map.hover_ui.hide_tile_panel()
		return
	var hex: Hex = tile_map.map_data[map_coords]
	if hex.active_tile_card == null:
		tile_map.hover_ui.hide_tile_panel()
		return
	tile_map.hover_ui.update_tile_panel_hover(map_coords, true)


func _placement_failure_message(hex: Hex) -> String:
	if hex.is_placement_blocked():
		return "Tile locked"
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return "Can't place here"
	if tile_card.type == TileCard.TileCardType.UTILITY:
		if hex.active_tile_card == null:
			return "Needs an occupied tile"
		return "Can't target this tile"
	if hex.active_tile_card != null:
		if tile_card.type == TileCard.TileCardType.UTILITY:
			return "Can't target this tile"
		return ""
	if not tile_card.can_place_on_tile(hex):
		return _placement_restriction_message(tile_card)
	return "Can't place here"


func _placement_restriction_message(tile_card: TileCard) -> String:
	match tile_card.placement_restriction:
		TileCard.PlacementRestriction.EDGE_TILE:
			return "Must be an edge tile"
		TileCard.PlacementRestriction.SEGMENT_FIRST_TILE:
			return "Must be a first segment tile"
		TileCard.PlacementRestriction.SEGMENT_LAST_TILE:
			return "Must be a last segment tile"
		TileCard.PlacementRestriction.ONE_TILE_SEGMENT:
			return "Must be a 1-tile segment"
		_:
			return "Can't place here"


func _show_placement_failed_feedback(hex: Hex, message: String) -> void:
	if message.is_empty():
		return
	var world_pos: Vector2
	if hex != null and hex.is_on_map():
		world_pos = tile_map.to_global(tile_map.base_layer.map_to_local(hex.coordinates))
	else:
		world_pos = tile_map.get_global_mouse_position()
	tile_map.create_floating_text(world_pos, message, Color(1.0, 0.45, 0.45, 1.0))


func _try_place_card() -> void:
	if selected_card == null or _is_placing:
		return
	
	var map_coords := _get_mouse_map_coords()
	
	if not tile_map.is_in_map(map_coords):
		_deselect_card()
		return
	
	var hex: Hex = tile_map.map_data[map_coords]
	if not tile_map.is_tile_interactable(map_coords) or not _can_place_on_hex(hex):
		var failure_message := _placement_failure_message(hex)
		if not failure_message.is_empty():
			_show_placement_failed_feedback(hex, failure_message)
		_deselect_card()
		return

	var tile_card := _get_selected_tile_card()
	if tile_card != null and tile_card.utility_target_count > 1:
		_collect_utility_target(hex)
		return

	_place_card_on_hex(hex)


func _clear_preview() -> void:
	_ghost_follow_mouse = false
	_is_placing = false
	if tile_map.hover_ui != null:
		tile_map.hover_ui.hide_tile_panel()
	if selected_card != null:
		selected_card.set_map_tile_hover_active(false, false)
		selected_card.reset_placement_morph()
	_rune_preview.visible = false
	_rune_preview.reset_ghost_visuals()
	_hide_tile_landing_preview()
	_clear_placement_overlays()


func _clear_placement_overlays() -> void:
	tile_map.clear_placement_preview()
	_clear_hover_highlights()
	_clear_restriction_overlays()
	_clear_valid_restriction_highlights()
	_clear_rune_highlights_at(_utility_target_coords)
	tile_map.rune_highlight_overlay_layer.modulate = Color.WHITE


func _clear_restriction_overlays() -> void:
	for coords: Vector2i in _restricted_invalid_coords:
		if tile_map.map_data[coords].is_placement_blocked():
			continue
		tile_map.disabled_tile_overlay_layer.set_cell(coords, -1)
	_restricted_invalid_coords.clear()


func _clear_valid_restriction_highlights() -> void:
	tile_map.clear_placement_valid_highlights()
	_valid_restriction_coords.clear()


func _clear_hover_highlights() -> void:
	_clear_rune_highlights_at(_effect_preview_coords)
	_effect_preview_coords.clear()


func _clear_rune_highlights_at(coords_list: Array[Vector2i]) -> void:
	for coords: Vector2i in coords_list:
		_clear_rune_highlight_at(coords)


func _clear_rune_highlight_at(coords: Vector2i) -> void:
	# Segment-row hover shares this layer, do not erase its tiles while that hover is active.
	if tile_map.has_hovered_segment_highlight_at(coords):
		return
	tile_map.rune_highlight_overlay_layer.set_cell(coords, -1)


## True while this handler currently stamps an effect-preview highlight on coords.
func is_highlighting_coord(coords: Vector2i) -> bool:
	return coords in _effect_preview_coords or coords in _utility_target_coords


func _stamp_valid_placement_highlight(coords: Vector2i) -> void:
	tile_map.stamp_placement_valid_highlight(coords)


func _stamp_effect_preview_highlight(coords: Vector2i) -> void:
	tile_map.rune_highlight_overlay_layer.set_cell(
		coords,
		tile_map.RUNE_HIGHLIGHT_SOURCE_ID,
		tile_map.OVERLAY_TILE_ATLAS_COORDS
	)


func _reset_state() -> void:
	selected_card = null
	is_card_selected = false
	_awaiting_pointer_release = false
	_select_press_position = Vector2.ZERO
	_ghost_follow_mouse = false
	_ghost_float_time = 0.0
	_is_placing = false
	_utility_target_hexes.clear()
	_utility_target_coords.clear()


func _has_dragged_from_select() -> bool:
	return tile_map.get_global_mouse_position().distance_to(_select_press_position) >= DRAG_PLACE_THRESHOLD_PX


func _show_cursor_rune_preview(morph_progress: float) -> void:
	if morph_progress <= 0.05:
		_rune_preview.visible = false
		return
	_ghost_follow_mouse = true
	_place_rune_preview_at_mouse()
	_rune_preview.modulate = Color.WHITE
	_rune_preview.visible = true


func _show_tile_landing_preview(hex: Hex) -> void:
	_tile_landing_preview.map = tile_map
	_tile_landing_preview.tile = hex
	_tile_landing_preview.global_position = _hex_ghost_target_position(hex)
	_tile_landing_preview.set_ghost_float_scale(1.0)
	_tile_landing_preview.modulate = TILE_LANDING_PREVIEW_COLOR
	_tile_landing_preview.visible = true
	var tile_card := _get_selected_tile_card()
	if tile_card != null:
		_tile_landing_preview.refresh_output_chip(tile_card)


func _hide_tile_landing_preview() -> void:
	_tile_landing_preview.visible = false
	_tile_landing_preview.tile = null
	_tile_landing_preview.hide_output_chip()


func _place_rune_preview_at_mouse() -> void:
	var bob := sin(_ghost_float_time * TAU * GHOST_FLOAT_HZ) * GHOST_FLOAT_AMPLITUDE
	var pulse := 1.0 + sin(_ghost_float_time * TAU * GHOST_FLOAT_HZ) * GHOST_FLOAT_SCALE_PULSE
	_rune_preview.global_position = (
		tile_map.get_global_mouse_position()
		- HexTileMap.HEX_RUNE_SIZE / 2.0
		+ Vector2(0.0, GHOST_LIFT_OFFSET + bob)
	)
	_rune_preview.set_ghost_float_scale(pulse)


func _hex_ghost_target_position(hex: Hex) -> Vector2:
	# Match Hex._fit_rune_ui so the ghost lands where the placed rune will sit.
	if hex.is_on_map():
		return hex.items_grid.global_position + (Hex.HEX_TILE_SIZE - Hex.HEX_RUNE_SIZE) * 0.5
	var tile_center: Vector2 = tile_map.base_layer.map_to_local(hex.coordinates)
	return tile_map.to_global(tile_center - Hex.HEX_RUNE_SIZE * 0.5)


func _place_card_on_hex(hex: Hex) -> void:
	_is_placing = true
	_ghost_follow_mouse = false
	_hide_tile_landing_preview()
	if tile_map.hover_ui != null:
		tile_map.hover_ui.hide_tile_panel()
	await _animate_ghost_snap_into_hex(hex)
	if selected_card == null or selected_card.card == null:
		_is_placing = false
		return
	_rune_preview.visible = false
	selected_card.card.play_on(hex, false)
	_finish_playing_selected_card()


func _animate_ghost_snap_into_hex(hex: Hex) -> void:
	if not _rune_preview.visible:
		_rune_preview.visible = true
	var snap_duration := 0.0 if GameManager.skip_presentation else GHOST_SNAP_DURATION
	await _rune_preview.animate_ghost_snap_to(_hex_ghost_target_position(hex), snap_duration)
	if GameManager.skip_presentation:
		return
	await _rune_preview.play_drag_seat_animation()


# Disables invalid tiles and highlights valid ones for runes with placement restrictions.
func _update_placement_overlays() -> void:
	_clear_placement_overlays()
	
	var tile_card := _get_selected_tile_card()
	if tile_card == null or not tile_card.has_placement_restriction():
		return
	
	for coords: Vector2i in tile_map.map_data:
		var hex: Hex = tile_map.map_data[coords]
		if not _is_placement_candidate(hex):
			continue
		
		if tile_card.can_place_on_tile(hex):
			_stamp_valid_placement_highlight(coords)
			_valid_restriction_coords.append(coords)
			continue
		
		_restricted_invalid_coords.append(coords)
		if not hex.is_placement_blocked():
			tile_map.disabled_tile_overlay_layer.set_cell(
				coords,
				tile_map.OVERLAY_TILE_SOURCE_ID,
				tile_map.OVERLAY_TILE_ATLAS_COORDS
			)


# Highlights tiles the hovered card would affect. The placement tile itself stays unhighlighted.
func _update_hover_highlights(hover_hex: Hex) -> void:
	_clear_hover_highlights()
	_restamp_utility_target_highlights()
	
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return
	
	var placement_coords := hover_hex.coordinates
	for coords: Vector2i in tile_card.get_trigger_preview_coords(hover_hex):
		if not tile_map.is_in_map(coords):
			continue
		if coords == placement_coords:
			continue
		_stamp_effect_preview_highlight(coords)
		_effect_preview_coords.append(coords)


func _get_selected_tile_card() -> TileCard:
	if selected_card == null or not (selected_card.card is TileCard):
		return null
	return selected_card.card as TileCard


# Tiles that can receive the currently selected card before restriction checks.
func _is_placement_candidate(hex: Hex) -> bool:
	if selected_card == null or selected_card.card == null:
		return false
	return selected_card.card.is_placement_candidate(hex)


# Delegates occupancy, restrictions, and attach rules to the selected Card.
func _can_place_on_hex(hex: Hex) -> bool:
	if selected_card == null or selected_card.card == null:
		return false
	var tile_card := _get_selected_tile_card()
	if tile_card != null and tile_card.utility_target_count > 1:
		return tile_card.can_utility_target(hex, _utility_target_hexes)
	return selected_card.card.can_play_on(hex)


## Stores one occupied hex for a multi-target utility. Resolves when the last target is chosen.
func _collect_utility_target(hex: Hex) -> void:
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return

	_utility_target_hexes.append(hex)
	_utility_target_coords.append(hex.coordinates)
	_stamp_effect_preview_highlight(hex.coordinates)

	if _utility_target_hexes.size() < tile_card.utility_target_count:
		return

	_place_utility_on_targets(tile_card)


func _place_utility_on_targets(tile_card: TileCard) -> void:
	var last_hex := _utility_target_hexes.back() as Hex
	_is_placing = true
	_ghost_follow_mouse = false
	_hide_tile_landing_preview()
	if tile_map.hover_ui != null:
		tile_map.hover_ui.hide_tile_panel()
	if last_hex != null:
		await _animate_ghost_snap_into_hex(last_hex)
	if selected_card == null:
		_is_placing = false
		return
	_rune_preview.visible = false
	tile_card.apply_on_targets(_utility_target_hexes)
	_finish_playing_selected_card()


func _finish_playing_selected_card() -> void:
	EventBus.card_played.emit(selected_card)
	AudioManager.play_sfx(UISounds.GROUND_IMPACT)
	var card_to_remove := selected_card
	_clear_preview()
	_reset_state()
	card_to_remove.queue_free()


func _restamp_utility_target_highlights() -> void:
	for coords: Vector2i in _utility_target_coords:
		_stamp_effect_preview_highlight(coords)
