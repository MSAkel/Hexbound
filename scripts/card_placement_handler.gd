# Owns the pick-up, aim and drop of a hand card onto the hex tile map.
# Every pick-up starts with EventBus.card_drag_started and ends with exactly one
# EventBus.card_drag_ended, whether the card was played, sold or put back.
class_name CardPlacementHandler
extends Node


## How a pick-up ended. Sent with EventBus.card_drag_ended.
enum DragOutcome {
	CANCELLED,
	PLAYED,
	SOLD,
}

# Reference to the tile map.
var tile_map: HexTileMap

## Hand card currently picked up, or null.
var selected_card: CardUI = null
## True while a hand card is picked up for placement.
var is_card_selected: bool:
	get:
		return selected_card != null

# True from a drop on a legal hex until play_on commits. Cancel input is ignored meanwhile.
var _is_placing := false
# Ghost of the picked card. It follows the cursor, or the focused hex on a controller.
var _rune_preview: CardIconUI
# Holds the dragged ghost above the HUD (staff column included). Mirrors the map's transform,
# so the ghost keeps working in map-canvas coordinates.
var _drag_ghost_root: Node2D
# Faded copy snapped to the hex the dragged rune would land on.
var _tile_landing_preview: CardIconUI
# Tiles temporarily marked invalid while a card is held.
var _restricted_invalid_coords: Array[Vector2i] = []
# Tiles currently showing trigger-effect preview highlights.
var _effect_preview_coords: Array[Vector2i] = []
# Station seats whose cards count toward a Meal's requirements or output.
var _effect_preview_gold_coords: Array[Vector2i] = []
# Valid placement tiles highlighted while a card is held. Meals light Meal slots, others the rest.
var _valid_restriction_coords: Array[Vector2i] = []
# Legal hex whose landing preview and effect highlights are showing, or NO_CELL.
var _previewed_cell := NO_CELL
# True until the mouse-up that belongs to the drag that picked the card up.
var _awaiting_pointer_release := false
# Preview follows the gamepad hex cursor instead of the mouse.
var _use_gamepad_preview := false
var _ghost_float_time := 0.0
# Smoothed ghost position, before the float bob is added.
var _ghost_position := Vector2.ZERO
var _ghost_tilt := 0.0
var _ghost_tint_target := Color.WHITE
# Scale multiplier that pops the ghost in on pick-up.
var _ghost_pickup_scale := 1.0
var _pickup_tween: Tween
# Flies the ghost back to the hand or into the sell panel after the pick-up has ended.
var _ghost_exit_tween: Tween

const NO_CELL := Vector2i(-1, -1)
# Loaded at runtime, not preloaded. card_icon_ui.gd types its map as HexTileMap, which owns this
# handler, so a preload forms a cycle and comes back empty when hex_tile_map.tscn loads first.
const CARD_ICON_UI_PATH := "res://scenes/cards/card_icon_ui/card_icon_ui.tscn"
# Ghost tint over a spot the card cannot be dropped on.
const INVALID_GHOST_TINT := Color(1.0, 0.45, 0.45, 0.75)
# Dropping here destroys the seated card.
const REPLACE_GHOST_TINT := Color(1.0, 0.72, 0.35, 0.9)
# How fast the tint blends. Higher is snappier.
const GHOST_TINT_SPEED := 18.0
# Bob height in pixels. Raise for more float, lower toward 0 to calm it.
const GHOST_FLOAT_AMPLITUDE := 2.0
# Cycles per second. Raise to bob faster, lower to bob slower.
const GHOST_FLOAT_HZ := 0.85
# Extra scale swing around 1. Set to 0 to disable the pulse.
const GHOST_FLOAT_SCALE_PULSE := 0.006
# How tightly the ghost trails its target. Higher is stiffer, lower is floatier.
const GHOST_FOLLOW_SPEED := 30.0
# Lean into horizontal travel, in radians per pixel per second. Set to 0 for no tilt.
const GHOST_TILT_PER_SPEED := 0.00025
const GHOST_MAX_TILT_DEGREES := 7.0
const GHOST_TILT_SPEED := 14.0
# The ghost pops in from this scale when a card is picked up.
const GHOST_PICKUP_START_SCALE := 0.6
const GHOST_PICKUP_DURATION := 0.14
# Glide duration on release. Keep this short so the drop reads as a fall, not a float.
const GHOST_SNAP_DURATION := 0.10
# Flight back to the hand after a cancel, and into the sell panel after a sale.
const GHOST_RETURN_DURATION := 0.16
const GHOST_SELL_DURATION := 0.2
const GHOST_EXIT_SCALE := 0.35
# Vertical lift while dragging. Negative Y floats the ghost above the board.
const GHOST_LIFT_OFFSET := -7.0
# Above trigger-order numbers (25) and path traces (22) on the map.
const DRAGGED_RUNE_Z_INDEX := 40
## Canvas layer of the dragged ghost. Above MainUI (layer 1) so the card stays over the HUD.
const DRAG_GHOST_CANVAS_LAYER := 2
const TILE_LANDING_PREVIEW_Z_INDEX := 6
const TILE_LANDING_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.4)


## True while a drop is animating in. The card is not yet committed to the map.
func is_placement_in_progress() -> bool:
	return _is_placing


func _ready() -> void:
	EventBus.card_drag_requested.connect(_on_card_drag_requested)
	EventBus.turn_ended.connect(_on_turn_ended)
	var card_icon_scene := load(CARD_ICON_UI_PATH) as PackedScene
	_drag_ghost_root = _make_drag_ghost_root()
	_rune_preview = _make_ghost_rune(card_icon_scene, DRAGGED_RUNE_Z_INDEX, _drag_ghost_root)
	_tile_landing_preview = _make_ghost_rune(card_icon_scene, TILE_LANDING_PREVIEW_Z_INDEX, tile_map)


## A camera-following canvas layer above the HUD, with a root that copies the map's transform.
func _make_drag_ghost_root() -> Node2D:
	var layer := CanvasLayer.new()
	layer.name = "DragGhostLayer"
	layer.layer = DRAG_GHOST_CANVAS_LAYER
	layer.follow_viewport_enabled = true
	tile_map.add_child(layer)
	var root := Node2D.new()
	root.name = "DragGhostRoot"
	layer.add_child(root)
	_sync_drag_ghost_root(root)
	return root


func _sync_drag_ghost_root(root: Node2D) -> void:
	root.transform = tile_map.global_transform


func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


func _make_ghost_rune(scene: PackedScene, z: int, parent: Node) -> CardIconUI:
	var ghost := scene.instantiate() as CardIconUI
	ghost.visible = false
	ghost.z_index = z
	ghost.custom_minimum_size = HexTileMap.HEX_RUNE_SIZE
	ghost.size = HexTileMap.HEX_RUNE_SIZE
	ghost.pivot_offset = HexTileMap.HEX_RUNE_SIZE / 2.0
	parent.add_child(ghost)
	ghost.prepare_placement_ghost()
	return ghost


func _process(delta: float) -> void:
	if _rune_preview.visible:
		_sync_drag_ghost_root(_drag_ghost_root)
	if selected_card == null or _is_placing:
		return
	_ghost_float_time += delta
	_update_ghost_motion(delta)


func _input(event: InputEvent) -> void:
	if selected_card == null or _is_placing:
		return

	if event.is_action_pressed("right_mouse") or event.is_action_pressed("ui_cancel"):
		_cancel_selection()
		get_viewport().set_input_as_handled()
		return

	# Tracked here so the preview keeps up while the cursor crosses HUD controls.
	if event is InputEventMouseMotion:
		_update_rune_preview()
		return

	if not _awaiting_pointer_release:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_awaiting_pointer_release = false
		_drop_at_cursor()
		# Hand took the matching press before any Control saw it, so nothing waits on this release.
		get_viewport().set_input_as_handled()


## Click-to-place. Only reached when a controller pick-up was handed over to the mouse,
## so there is no held button whose release would drop the card.
func _unhandled_input(event: InputEvent) -> void:
	if selected_card == null or _is_placing:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_drop_at_cursor()
		get_viewport().set_input_as_handled()


#region Pick-up lifecycle

func _on_card_drag_requested(card: CardUI) -> void:
	_begin_selection(card, false)


## Pick a hand card up with the controller. Skips the mouse drag.
func begin_gamepad_placement(card: CardUI) -> void:
	if card == null:
		return
	if selected_card == card:
		_configure_gamepad_placement()
		_update_rune_preview()
		return
	_begin_selection(card, true)


func _begin_selection(card: CardUI, use_gamepad: bool) -> void:
	if _is_placing:
		return
	if selected_card != null:
		_end_selection(DragOutcome.CANCELLED)

	selected_card = card
	EventBus.card_drag_started.emit(card)
	_update_preview_texture()
	_update_placement_overlays()

	if use_gamepad:
		_configure_gamepad_placement()
	else:
		_use_gamepad_preview = false
		# The card was picked up on mouse-down. The matching mouse-up drops it.
		_awaiting_pointer_release = true
	_show_ghost_for_pickup()
	_update_rune_preview()


func _configure_gamepad_placement() -> void:
	_awaiting_pointer_release = false
	_use_gamepad_preview = true
	tile_map.ensure_gamepad_focus()
	_focus_gamepad_on_placeable_tile()


## Clears every preview and reports how the pick-up ended. Callers deal with the cursor ghost.
func _end_selection(outcome: DragOutcome) -> void:
	var card := selected_card
	if card == null:
		return
	if tile_map.hover_ui != null:
		tile_map.hover_ui.hide_tile_panel()
	_hide_tile_landing_preview()
	_clear_placement_overlays()
	_previewed_cell = NO_CELL
	selected_card = null
	_awaiting_pointer_release = false
	_use_gamepad_preview = false
	_is_placing = false
	EventBus.card_drag_ended.emit(card, outcome)


## Puts the picked card back in the hand.
func _cancel_selection(fly_back: bool = true) -> void:
	var card := selected_card
	if card == null:
		return
	_end_selection(DragOutcome.CANCELLED)
	if fly_back and _rune_preview.visible and not GameManager.skip_presentation:
		_fly_ghost_to(_control_center_in_world(card), GHOST_RETURN_DURATION)
	else:
		_hide_ghost()


func cancel_gamepad_placement() -> void:
	_cancel_selection()


## A resolving turn slides the hand away. Do not leave a card on the cursor.
func _on_turn_ended() -> void:
	if selected_card != null and not _is_placing:
		_cancel_selection(false)


## Keeps an active placement when the player switches from controller to mouse.
func switch_to_mouse_preview() -> void:
	if selected_card == null:
		return
	_use_gamepad_preview = false
	_awaiting_pointer_release = false
	_update_rune_preview()


func refresh_gamepad_preview() -> void:
	if _use_gamepad_preview and selected_card != null:
		_update_rune_preview()


func try_place_from_gamepad() -> void:
	if selected_card == null or _is_placing:
		return
	_try_place_card()

#endregion

#region Dropping

func _drop_at_cursor() -> void:
	# Released back on its own hand slot. Treat it as a change of mind.
	if _is_cursor_over_hand_slot():
		_cancel_selection()
		return
	var sell_panel := get_tree().get_first_node_in_group("card_sell_panel") as CardSellPanel
	if sell_panel != null and sell_panel.is_cursor_over():
		_sell_selected_card(sell_panel)
		return
	_try_place_card()


func _is_cursor_over_hand_slot() -> bool:
	var map_coords := _get_active_map_coords()
	# The fan overlaps the bottom hexes. A reachable tile wins over the slot beneath it.
	if tile_map.is_in_map(map_coords) and tile_map.is_tile_interactable(map_coords):
		return false
	return selected_card.is_mouse_over()


func _sell_selected_card(sell_panel: CardSellPanel) -> void:
	var card := selected_card
	sell_panel.sell_card()
	_end_selection(DragOutcome.SOLD)
	EventBus.card_sold.emit(card)
	card.queue_free()
	if not _rune_preview.visible or GameManager.skip_presentation:
		_hide_ghost()
		sell_panel.play_sell_pulse()
		return
	_fly_ghost_to(_control_center_in_world(sell_panel), GHOST_SELL_DURATION, func() -> void:
		if is_instance_valid(sell_panel):
			sell_panel.play_sell_pulse()
	)


func _try_place_card() -> void:
	if selected_card == null or _is_placing:
		return

	var map_coords := _get_active_map_coords()

	if not tile_map.is_in_map(map_coords):
		_cancel_selection()
		return

	var hex: Hex = tile_map.map_data[map_coords]
	if not tile_map.is_tile_interactable(map_coords) or not _can_place_on_hex(hex):
		_show_placement_failed_feedback(hex, _placement_failure_message(hex))
		_cancel_selection()
		return

	_place_card_on_hex(hex)


func _place_card_on_hex(hex: Hex) -> void:
	# The drop is committed from here. Remember the card, since the snap is awaited.
	var card := selected_card
	_is_placing = true
	_hide_tile_landing_preview()
	if tile_map.hover_ui != null:
		tile_map.hover_ui.hide_tile_panel()
	await _animate_ghost_snap_into_hex(hex)
	if selected_card != card or not is_instance_valid(card) or card.card == null:
		_is_placing = false
		return
	_hide_ghost()
	card.card.play_on(hex, false)
	# Ghost hide would kill in-flight particles. Burst on the seated rune instead.
	if hex.card_icon_ui != null and not GameManager.skip_presentation:
		hex.card_icon_ui.play_placement_land_particles()
	EventBus.card_played.emit(card)
	AudioManager.play_sfx(UISounds.GROUND_IMPACT)
	_end_selection(DragOutcome.PLAYED)
	card.queue_free()


func _animate_ghost_snap_into_hex(hex: Hex) -> void:
	_kill_ghost_tweens()
	_rune_preview.visible = true
	_rune_preview.set_ghost_float_scale(1.0)
	var snap_duration := 0.0 if GameManager.skip_presentation else GHOST_SNAP_DURATION
	await _rune_preview.animate_ghost_snap_to(_hex_ghost_target_position(hex), snap_duration)
	if GameManager.skip_presentation:
		return
	await _rune_preview.play_drag_seat_animation()


func _placement_failure_message(hex: Hex) -> String:
	if StationManager.is_meal_slot_locked(hex.coordinates):
		return "Unlocks at %s Lv %d" % [GameTerms.STATION, StationManager.MEAL_SLOT_UNLOCK_LEVEL]
	if hex.is_placement_blocked():
		return "%s locked" % GameTerms.SPOT
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return "Can't place here"
	if not tile_card.can_place_on_tile(hex):
		return _meal_slot_rule_message(tile_card)
	if hex.active_tile_card != null and hex.active_tile_card.id == tile_card.id:
		return "Already %s" % TileCard.star_text(TileCard.MAX_STAR_LEVEL)
	return "Can't place here"


func _meal_slot_rule_message(tile_card: TileCard) -> String:
	if tile_card.type == TileCard.TileCardType.MEAL:
		return "%ss go in the last two %ss" % [GameTerms.MEAL, GameTerms.SPOT.to_lower()]
	return "%ss only" % GameTerms.MEAL_SLOT


func _show_placement_failed_feedback(hex: Hex, message: String) -> void:
	if message.is_empty():
		return
	var world_pos: Vector2
	if hex != null and hex.is_on_map():
		world_pos = tile_map.floating_text_position_for_hex(hex.coordinates)
	else:
		world_pos = tile_map.get_global_mouse_position()
	tile_map.create_floating_text(world_pos, message, Color(1.0, 0.45, 0.45, 1.0))
	if not GameManager.skip_presentation:
		AudioManager.play_sfx(UISounds.CLICK)

#endregion

#region Aiming preview

func _update_preview_texture() -> void:
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return
	_rune_preview.prepare_placement_ghost()
	_rune_preview.setup(tile_card)
	_rune_preview.hide_output_chip()
	# The ghost draws above the HUD, so it must not catch the hover meant for what is under it.
	_ignore_mouse_recursive(_rune_preview)
	_tile_landing_preview.prepare_placement_ghost()
	_tile_landing_preview.setup(tile_card)
	_tile_landing_preview.hide_output_chip()


## Re-aims the preview at the hex under the cursor or controller focus.
func _update_rune_preview() -> void:
	if selected_card == null or _is_placing:
		return

	var map_coords := _get_active_map_coords()
	var hex: Hex = tile_map.map_data.get(map_coords) if tile_map.is_in_map(map_coords) else null
	var over_interactable_map := hex != null and tile_map.is_tile_interactable(map_coords)
	var over_valid_tile := over_interactable_map and _can_place_on_hex(hex)
	var overplay := _get_overplay(hex) if over_valid_tile else TileCard.Overplay.NONE

	# Warn before the drop, not after it.
	if over_interactable_map and not over_valid_tile:
		_ghost_tint_target = INVALID_GHOST_TINT
	elif overplay == TileCard.Overplay.REPLACE:
		_ghost_tint_target = REPLACE_GHOST_TINT
	else:
		_ghost_tint_target = Color.WHITE
	_update_placed_card_tile_panel(map_coords)

	# Highlights and the output chip only change when the targeted hex does.
	var target_cell := map_coords if over_valid_tile else NO_CELL
	if target_cell == _previewed_cell:
		return
	_previewed_cell = target_cell

	if over_valid_tile:
		# Chip rides on the cursor ghost so it is not hidden under the icon.
		tile_map.set_placement_preview_cell(map_coords)
		_show_tile_landing_preview(hex)
		var tile_card := _get_selected_tile_card()
		if tile_card != null:
			_rune_preview.tile = hex
			if overplay == TileCard.Overplay.MERGE:
				_rune_preview.refresh_output_chip(_merge_preview_card(tile_card, hex.active_tile_card))
			else:
				_rune_preview.refresh_output_chip(tile_card)
		_update_hover_highlights(hex)
	else:
		_hide_tile_landing_preview()
		_rune_preview.tile = null
		_rune_preview.hide_output_chip()
		tile_map.clear_placement_preview()
		_clear_hover_highlights()


func _get_mouse_map_coords() -> Vector2i:
	return tile_map.base_layer.local_to_map(
		tile_map.to_local(tile_map.get_global_mouse_position())
	)


func _get_active_map_coords() -> Vector2i:
	if _use_gamepad_preview:
		var coords := tile_map.get_gamepad_focus_cell()
		if coords != Vector2i(-1, -1):
			return coords
	return _get_mouse_map_coords()


# Occupied tiles under the cursor show the placed card inspect panel while dragging to place.
func _update_placed_card_tile_panel(map_coords: Vector2i) -> void:
	if tile_map.hover_ui == null:
		return
	if not tile_map.is_in_map(map_coords) or not tile_map.is_tile_interactable(map_coords):
		tile_map.hover_ui.hide_tile_panel()
		return
	var hex: Hex = tile_map.map_data[map_coords]
	if hex.active_tile_card == null:
		tile_map.hover_ui.hide_tile_panel()
		return
	tile_map.hover_ui.update_tile_panel_hover(map_coords, true)


## Moves controller focus onto the nearest legal placement tile when the current cell cannot be used.
func _focus_gamepad_on_placeable_tile() -> void:
	var focus := tile_map.get_gamepad_focus_cell()
	if _is_placeable_map_coords(focus):
		return
	var origin := focus if focus != Vector2i(-1, -1) else tile_map.get_default_gamepad_focus_cell()
	var origin_pos := tile_map.base_layer.map_to_local(origin)
	var best := Vector2i(-1, -1)
	var best_dist_sq := INF
	for coords: Vector2i in tile_map.map_data:
		if not _is_placeable_map_coords(coords):
			continue
		var dist_sq := origin_pos.distance_squared_to(tile_map.base_layer.map_to_local(coords))
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = coords
	if best != Vector2i(-1, -1):
		tile_map.set_gamepad_focus_cell(best)


func _is_placeable_map_coords(coords: Vector2i) -> bool:
	if not tile_map.is_tile_interactable(coords):
		return false
	return _can_place_on_hex(tile_map.map_data[coords])


func _show_tile_landing_preview(hex: Hex) -> void:
	_tile_landing_preview.map = tile_map
	_tile_landing_preview.tile = hex
	_tile_landing_preview.global_position = _hex_ghost_target_position(hex)
	_tile_landing_preview.set_ghost_float_scale(1.0)
	_tile_landing_preview.modulate = TILE_LANDING_PREVIEW_COLOR
	_tile_landing_preview.visible = true
	_tile_landing_preview.hide_output_chip()


func _hide_tile_landing_preview() -> void:
	_tile_landing_preview.visible = false
	_tile_landing_preview.tile = null
	_tile_landing_preview.hide_output_chip()

#endregion

#region Cursor ghost

func _show_ghost_for_pickup() -> void:
	_kill_ghost_tweens()
	_ghost_float_time = 0.0
	_ghost_tilt = 0.0
	_ghost_tint_target = Color.WHITE
	_ghost_position = _ghost_target_position()
	_rune_preview.reset_ghost_visuals()
	_rune_preview.visible = true

	_ghost_pickup_scale = 1.0
	if not GameManager.skip_presentation:
		_ghost_pickup_scale = GHOST_PICKUP_START_SCALE
		_pickup_tween = create_tween()
		_pickup_tween.tween_property(
			self, "_ghost_pickup_scale", 1.0, GHOST_PICKUP_DURATION
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_ghost_motion(0.0)


## Trails the ghost behind its target with a little lag, lean and bob.
func _update_ghost_motion(delta: float) -> void:
	var previous_x := _ghost_position.x
	_ghost_position = _ghost_position.lerp(
		_ghost_target_position(), 1.0 - exp(-GHOST_FOLLOW_SPEED * delta)
	)
	if delta > 0.0:
		var max_tilt := deg_to_rad(GHOST_MAX_TILT_DEGREES)
		var target_tilt := clampf(
			(_ghost_position.x - previous_x) / delta * GHOST_TILT_PER_SPEED, -max_tilt, max_tilt
		)
		_ghost_tilt = lerpf(_ghost_tilt, target_tilt, 1.0 - exp(-GHOST_TILT_SPEED * delta))

	var wave := sin(_ghost_float_time * TAU * GHOST_FLOAT_HZ)
	_rune_preview.global_position = (
		_ghost_position + Vector2(0.0, GHOST_LIFT_OFFSET + wave * GHOST_FLOAT_AMPLITUDE)
	)
	_rune_preview.rotation = _ghost_tilt
	_rune_preview.set_ghost_float_scale(
		(1.0 + wave * GHOST_FLOAT_SCALE_PULSE) * _ghost_pickup_scale
	)
	_rune_preview.modulate = _rune_preview.modulate.lerp(
		_ghost_tint_target, 1.0 - exp(-GHOST_TINT_SPEED * delta)
	)


## Top-left corner the ghost is drawn toward. The focused hex on a controller, else the cursor.
func _ghost_target_position() -> Vector2:
	if _use_gamepad_preview:
		var coords := _get_active_map_coords()
		if tile_map.is_in_map(coords):
			return _hex_ghost_target_position(tile_map.map_data[coords])
	return tile_map.get_global_mouse_position() - HexTileMap.HEX_RUNE_SIZE / 2.0


func _hex_ghost_target_position(hex: Hex) -> Vector2:
	# Match Hex._fit_rune_ui so the ghost lands where the placed rune will sit.
	if hex.is_on_map():
		return hex.items_grid.global_position + (Hex.HEX_TILE_SIZE - Hex.HEX_RUNE_SIZE) * 0.5
	var tile_center: Vector2 = tile_map.base_layer.map_to_local(hex.coordinates)
	return tile_map.to_global(tile_center - Hex.HEX_RUNE_SIZE * 0.5)


## Shrinks the ghost into a point on the map canvas, then hides it. Used once the pick-up has ended.
func _fly_ghost_to(world_center: Vector2, duration: float, on_arrived: Callable = Callable()) -> void:
	_kill_ghost_tweens()
	_rune_preview.tile = null
	_rune_preview.hide_output_chip()
	_ghost_exit_tween = create_tween().set_parallel(true)
	_ghost_exit_tween.tween_property(
		_rune_preview, "global_position", world_center - HexTileMap.HEX_RUNE_SIZE / 2.0, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_exit_tween.tween_property(
		_rune_preview, "scale", Vector2.ONE * GHOST_EXIT_SCALE, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_exit_tween.tween_property(_rune_preview, "rotation", 0.0, duration)
	_ghost_exit_tween.tween_property(
		_rune_preview, "modulate:a", 0.0, duration
	).set_ease(Tween.EASE_IN)
	_ghost_exit_tween.chain().tween_callback(func() -> void:
		_hide_ghost()
		if on_arrived.is_valid():
			on_arrived.call()
	)


## Center of a HUD control in the map's world space, where the ghost lives.
func _control_center_in_world(control: Control) -> Vector2:
	var screen_pos := control.get_canvas_transform() * control.get_global_rect().get_center()
	return tile_map.get_canvas_transform().affine_inverse() * screen_pos


func _hide_ghost() -> void:
	_rune_preview.visible = false
	_rune_preview.tile = null
	_rune_preview.reset_ghost_visuals()


func _kill_ghost_tweens() -> void:
	if _pickup_tween != null and _pickup_tween.is_valid():
		_pickup_tween.kill()
	if _ghost_exit_tween != null and _ghost_exit_tween.is_valid():
		_ghost_exit_tween.kill()
	_ghost_pickup_scale = 1.0

#endregion

#region Board overlays

func _clear_placement_overlays() -> void:
	tile_map.clear_placement_preview()
	_clear_hover_highlights()
	_clear_restriction_overlays()
	_clear_valid_restriction_highlights()
	tile_map.card_highlight_overlay_layer.modulate = Color.WHITE


func _clear_restriction_overlays() -> void:
	for coords: Vector2i in _restricted_invalid_coords:
		if tile_map.map_data[coords].is_placement_blocked():
			continue
		tile_map.disabled_tile_overlay_layer.set_cell(coords, -1)
	_restricted_invalid_coords.clear()


func _clear_valid_restriction_highlights() -> void:
	tile_map.clear_placement_valid_highlights()
	tile_map.clear_placement_merge_highlights()
	_valid_restriction_coords.clear()


func _clear_hover_highlights() -> void:
	var gold := _effect_preview_gold_coords.duplicate()
	_clear_rune_highlights_at(_effect_preview_coords)
	_effect_preview_coords.clear()
	_effect_preview_gold_coords.clear()
	tile_map.clear_dish_recipe_gold_highlights_at(gold)


func _clear_rune_highlights_at(coords_list: Array[Vector2i]) -> void:
	for coords: Vector2i in coords_list:
		_clear_rune_highlight_at(coords)


func _clear_rune_highlight_at(coords: Vector2i) -> void:
	# Credit flash, inspect, and condiment aim share this layer. Do not erase their tiles.
	if tile_map.has_hovered_segment_highlight_at(coords):
		return
	tile_map.card_highlight_overlay_layer.set_cell(coords, -1)


## True while this handler currently stamps an effect-preview highlight on coords.
func is_highlighting_coord(coords: Vector2i) -> bool:
	return coords in _effect_preview_coords


func _stamp_valid_placement_highlight(coords: Vector2i) -> void:
	tile_map.stamp_placement_valid_highlight(coords)


func _stamp_effect_preview_highlight(coords: Vector2i) -> void:
	tile_map.card_highlight_overlay_layer.set_cell(
		coords,
		tile_map.CARD_HIGHLIGHT_SOURCE_ID,
		tile_map.OVERLAY_TILE_ATLAS_COORDS
	)


# Disables invalid tiles and highlights valid ones. Meals only fit Meal slots, everything else the rest.
func _update_placement_overlays() -> void:
	_clear_placement_overlays()
	
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return
	
	for coords: Vector2i in tile_map.map_data:
		var hex: Hex = tile_map.map_data[coords]
		if not _is_placement_candidate(hex):
			continue
		
		var overplay := tile_card.get_overplay(hex)
		if overplay == TileCard.Overplay.PLACE:
			_stamp_valid_placement_highlight(coords)
			_valid_restriction_coords.append(coords)
			continue
		if overplay == TileCard.Overplay.MERGE:
			tile_map.stamp_placement_merge_highlight(coords)
			continue
		# Seated cards stay unwashed when the drop would replace them or is not allowed.
		if hex.active_tile_card != null:
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
	
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return
	
	var placement_coords := hover_hex.coordinates
	var counted_coords := tile_card.get_trigger_preview_gold_coords(hover_hex)
	for coords: Vector2i in tile_card.get_trigger_preview_coords(hover_hex):
		if not tile_map.is_in_map(coords):
			continue
		if coords == placement_coords:
			continue
		if coords in counted_coords:
			tile_map.stamp_dish_recipe_gold_highlight(coords)
			_effect_preview_gold_coords.append(coords)
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


func _get_overplay(hex: Hex) -> TileCard.Overplay:
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return TileCard.Overplay.NONE
	return tile_card.get_overplay(hex)


# Chip preview for a merge: the seated card one star higher, keeping its board buffs.
func _merge_preview_card(tile_card: TileCard, seated: TileCard) -> TileCard:
	var preview := tile_card.duplicate(true) as TileCard
	preview.star_level = seated.star_level + 1
	preview.bonus_production_amount = seated.bonus_production_amount
	return preview


# Delegates occupancy, restrictions, and attach rules to the selected Card.
func _can_place_on_hex(hex: Hex) -> bool:
	if selected_card == null or selected_card.card == null:
		return false
	return selected_card.card.can_play_on(hex)

#endregion
