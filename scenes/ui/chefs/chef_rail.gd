class_name ChefRail
extends Control

## Chef column fixed to the left edge of the screen. One hex per station, top to bottom,
## staggered like the rows of the pass.
## Drag a chef onto another hex to move or swap it, or onto the Sell panel to sell it.
## Sits above the merchant in the tree so chefs stay usable while the shop is open.

const SLOT_SCENE := preload("res://scenes/ui/chefs/chef_slot.tscn")
# Same on-screen size and spacing as a spot on the pass.
const SLOT_SIZE := Vector2(130, 151)
const SLOT_GAP := 10.0
# Gap between the column and the left edge of the screen.
const EDGE_MARGIN := 12.0
const FADE_DURATION := 0.3
const LOCKED_MESSAGE := "Chefs are busy"

@onready var _tile_panel: TilePanel = get_node_or_null("../TerrainTileUI")
@onready var _merchant: Control = get_node_or_null("../Merchant")

var _slots: Array[ChefSlot] = []
var _ghost: ChefSlot
var _tile_map: HexTileMap
# False while a full-screen overlay such as the card pick or Day summary covers the run.
var _shown := true
var _fade_tween: Tween
var _drag_slot := -1
# Shelf card a just-bought chef flies in from. Consumed by the next chef_added.
var _arrival_origin := Rect2()
var _has_arrival_origin := false
# Where the dragged chef was released, so its landing starts from the cursor.
var _drop_origin := Vector2.ZERO
var _has_drop_origin := false
# Controller: focused slot, and the slot of the chef being carried (-1 when none).
var _controller_focus := -1
var _controller_held := -1


func _ready() -> void:
	add_to_group("chef_rail")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ChefManager.SLOT_COUNT:
		var slot: ChefSlot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.drag_started.connect(_on_slot_drag_started)
		slot.hover_changed.connect(_on_slot_hover_changed)
		add_child(slot)
		_slots.append(slot)
	_ghost = SLOT_SCENE.instantiate()
	add_child(_ghost)
	_ghost.configure_as_ghost()
	_ghost.z_index = 30
	_ghost.hide()

	EventBus.chef_roster_changed.connect(_refresh)
	EventBus.chef_added.connect(_on_chef_added)
	EventBus.chef_moved.connect(_on_chef_moved)
	EventBus.chef_effect_triggered.connect(_on_chef_effect_triggered)
	EventBus.turn_ended.connect(_on_turn_ended)
	UiManager.active_panel_changed.connect(_on_active_panel_changed)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	# Sibling HUD nodes and the map finish their own layout after this node is ready.
	_layout.call_deferred()


func _process(_delta: float) -> void:
	if _drag_slot >= 0:
		_place_ghost_at_mouse()
		_update_drop_targets()


func _input(event: InputEvent) -> void:
	if _drag_slot < 0:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	# Right click puts the chef back in its hex.
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drop()
		# Leave this mouse-up unhandled. The slot Control that took the press must
		# still see the release, or Viewport keeps GUI mouse focus on the column.


## Merchant calls this right before seating a bought chef so it flies in from the shelf.
func set_next_arrival_origin(shelf_rect: Rect2) -> void:
	_arrival_origin = shelf_rect
	_has_arrival_origin = true


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].set_chef(ChefManager.get_chef(i))
		_slots[i].set_lifted(_drag_slot == i)


#region --- Layout ---

## Honeycomb column against the left edge, centered vertically on the pass. Slot 0 is the top hex.
## Pointy-top hexes interlock, so rows sit three quarters of a hex apart and every
## other one shifts sideways by half a cell. Even slots sit inward, like the short rows of the pass.
func _slot_rects() -> Array[Rect2]:
	var viewport_size := get_viewport_rect().size
	var pitch := SLOT_SIZE.y * 0.75 + SLOT_GAP
	var stagger := (SLOT_SIZE.x + SLOT_GAP) * 0.5
	var column_height := pitch * float(_slots.size() - 1) + SLOT_SIZE.y
	var top := _board_center_y(viewport_size) - column_height * 0.5
	var rects: Array[Rect2] = []
	for i in _slots.size():
		var x := EDGE_MARGIN + (stagger if i % 2 == 1 else 0.0)
		rects.append(Rect2(Vector2(x, top + pitch * float(i)), SLOT_SIZE))
	return rects


## Screen Y of the middle of the pass, so the column follows the board when it is moved.
## Falls back to the middle of the screen when there is no board.
func _board_center_y(viewport_size: Vector2) -> float:
	if _tile_map == null:
		return viewport_size.y * 0.5
	return _tile_map.get_map_screen_center().y


func _layout() -> void:
	if not is_instance_valid(_tile_map):
		_tile_map = _find_tile_map()
	var rects := _slot_rects()
	var centers: Array[Vector2] = []
	for i in _slots.size():
		_slots[i].position = rects[i].position
		_slots[i].size = rects[i].size
		centers.append(rects[i].get_center())
	_ghost.size = SLOT_SIZE
	# Bolts and payout text start at the chef, so the board needs to know where each one is.
	if _tile_map != null:
		_tile_map.set_chef_screen_centers(centers)


## Chefs stay up for the run and the merchant. Every other overlay hides them.
func _on_active_panel_changed(panel: Control) -> void:
	var shown := panel == null or not is_instance_valid(panel) or panel == _merchant
	if shown == _shown:
		return
	_shown = shown
	if not shown:
		_cancel_drag()
		_hide_inspect()
	for slot: ChefSlot in _slots:
		slot.set_interactive(shown)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var target_alpha := 1.0 if shown else 0.0
	if GameManager.skip_presentation:
		modulate.a = target_alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target_alpha, FADE_DURATION)

#endregion --- Layout ---


#region --- Drag and drop ---

func _on_slot_drag_started(index: int) -> void:
	if _drag_slot >= 0 or not _shown:
		return
	var chef := ChefManager.get_chef(index)
	if chef == null:
		return
	if not ChefManager.can_rearrange():
		_slots[index].play_reject()
		_show_message(index, LOCKED_MESSAGE)
		return
	_drag_slot = index
	_hide_inspect()
	AudioManager.play_sfx(UISounds.CONDIMENT_GRAB)
	_ghost.set_chef(chef)
	_ghost.modulate = Color.WHITE
	_ghost.show()
	_place_ghost_at_mouse()
	_refresh()
	EventBus.chef_drag_started.emit(index)


func _place_ghost_at_mouse() -> void:
	_ghost.global_position = get_global_mouse_position() - _ghost.size * 0.5


func _slot_under_mouse() -> int:
	var mouse := get_global_mouse_position()
	for i in _slots.size():
		if _slots[i].get_global_rect().has_point(mouse):
			return i
	return -1


func _update_drop_targets() -> void:
	var target := _slot_under_mouse()
	for i in _slots.size():
		_slots[i].set_drop_target(i == target and i != _drag_slot)


func _clear_drop_targets() -> void:
	for slot: ChefSlot in _slots:
		slot.set_drop_target(false)


func _finish_drop() -> void:
	var source := _drag_slot
	if source < 0:
		return
	var target := _slot_under_mouse()
	_drop_origin = get_global_mouse_position()

	if target >= 0 and target != source:
		_has_drop_origin = true
		_end_drag()
		if not ChefManager.move_chef(source, target):
			_has_drop_origin = false
			_slots[source].play_travel_from(_drop_origin)
		return

	var sell_panel := _find_sell_panel()
	if target < 0 and sell_panel != null and sell_panel.try_sell_chef(source):
		_finish_sell_drag(sell_panel)
		return

	# Released over its own hex or over nothing. Glide back home.
	_end_drag()
	_slots[source].play_travel_from(_drop_origin)


func _cancel_drag() -> void:
	var source := _drag_slot
	if source < 0:
		return
	var from := _ghost.get_global_center()
	_end_drag()
	_slots[source].play_travel_from(from)


## Clears drag state. The roster is unchanged, so the source hex shows its chef again.
func _end_drag() -> void:
	if _drag_slot >= 0 and _drag_slot < _slots.size():
		_slots[_drag_slot].clear_press()
	_drag_slot = -1
	_ghost.hide()
	_clear_drop_targets()
	_refresh()
	EventBus.chef_drag_ended.emit()
	EventBus.tooltip_hover_refresh_requested.emit()


## The chef is already sold. The ghost shrinks into the panel before it disappears.
func _finish_sell_drag(sell_panel: CardSellPanel) -> void:
	if _drag_slot >= 0 and _drag_slot < _slots.size():
		_slots[_drag_slot].clear_press()
	_drag_slot = -1
	_clear_drop_targets()
	_refresh()
	EventBus.chef_drag_ended.emit()
	var target := sell_panel.get_global_rect().get_center()
	_ghost.play_sell_into(target, func() -> void:
		_ghost.hide()
		EventBus.tooltip_hover_refresh_requested.emit()
	)

#endregion --- Drag and drop ---


#region --- Roster feedback ---

func _on_chef_added(slot: int) -> void:
	_refresh()
	if slot < 0 or slot >= _slots.size():
		return
	if _has_arrival_origin:
		_has_arrival_origin = false
		_slots[slot].play_arrival(_arrival_origin.get_center())
		return
	_slots[slot].play_travel_from(_slots[slot].get_global_center())


## Both hexes already hold their new chefs. Each one travels in from where it used to be.
func _on_chef_moved(from_slot: int, to_slot: int) -> void:
	_refresh()
	var from_center := _slots[from_slot].get_global_center()
	var to_center := _slots[to_slot].get_global_center()
	# The moved chef lands from the cursor after a drag, or from its old hex otherwise.
	var moved_origin := _drop_origin if _has_drop_origin else from_center
	var moved_bulge := 0.0 if _has_drop_origin else ChefSlot.TRAVEL_BULGE
	_has_drop_origin = false
	_slots[to_slot].play_travel_from(moved_origin, moved_bulge, true)
	# A displaced chef bows the other way so the two pass side by side.
	if ChefManager.get_chef(from_slot) != null:
		_slots[from_slot].play_travel_from(to_center, ChefSlot.TRAVEL_BULGE)


func _on_chef_effect_triggered(slot: int) -> void:
	if slot < 0 or slot >= _slots.size():
		return
	_slots[slot].play_effect_pulse(ChefManager.resolve_effect_at(slot))


func _on_turn_ended() -> void:
	_cancel_drag()
	_cancel_controller_hold()
	_hide_inspect()

#endregion --- Roster feedback ---


#region --- Inspect ---

func _on_slot_hover_changed(index: int, hovered: bool) -> void:
	if _tile_panel == null or _drag_slot >= 0:
		return
	var chef := ChefManager.get_chef(index)
	if not hovered or chef == null:
		_hide_inspect()
		return
	_show_inspect(index)


func _show_inspect(index: int) -> void:
	var chef := ChefManager.get_chef(index)
	if _tile_panel == null or chef == null:
		return
	_tile_panel.show_card(
		chef,
		_slots[index].get_global_rect(),
	)


func _hide_inspect() -> void:
	if _tile_panel == null:
		return
	for i in _slots.size():
		_tile_panel.hide_card(ChefManager.get_chef(i))


func _show_message(index: int, text: String) -> void:
	EventBus.toggle_tooltip.emit(true, text, _slots[index].get_global_rect())

#endregion --- Inspect ---


#region --- Controller ---

## Focus moves over the five hexes, plus a Sell target below them while carrying a chef.
func ensure_controller_focus() -> void:
	_move_controller_focus_to(maxi(_controller_focus, 0))


func clear_controller_focus() -> void:
	_cancel_controller_hold()
	_controller_focus = -1
	_apply_controller_focus_visual()
	_hide_inspect()


func move_controller_focus(direction: int) -> void:
	var next := 0 if _controller_focus < 0 else _controller_focus + direction
	_move_controller_focus_to(next)


func is_controller_holding() -> bool:
	return _controller_held >= 0


## Confirm picks a chef up. Confirm again drops it on the focused hex or sells it.
func activate_controller_focus() -> void:
	if _controller_focus < 0:
		return
	if _controller_held < 0:
		if _controller_focus >= _slots.size() or ChefManager.get_chef(_controller_focus) == null:
			return
		if not ChefManager.can_rearrange():
			_slots[_controller_focus].play_reject()
			return
		_controller_held = _controller_focus
		AudioManager.play_sfx(UISounds.CONDIMENT_GRAB)
		EventBus.chef_drag_started.emit(_controller_held)
		_announce_controller_focus()
		return

	var source := _controller_held
	var target := _controller_focus
	_controller_held = -1
	EventBus.chef_drag_ended.emit()
	if target == _sell_index():
		var sell_panel := _find_sell_panel()
		if sell_panel != null:
			sell_panel.sell_chef_from_controller(source)
		_move_controller_focus_to(source)
		return
	if target != source:
		ChefManager.move_chef(source, target)
	_announce_controller_focus()


## Back drops the carried chef where it was. Returns true when there was one to drop.
func cancel_controller_hold() -> bool:
	if _controller_held < 0:
		return false
	_cancel_controller_hold()
	_announce_controller_focus()
	return true


func _cancel_controller_hold() -> void:
	if _controller_held < 0:
		return
	_controller_held = -1
	EventBus.chef_drag_ended.emit()


func _move_controller_focus_to(index: int) -> void:
	# The Sell target only exists while a chef is being carried.
	var last := _sell_index() if _controller_held >= 0 else _slots.size() - 1
	_controller_focus = clampi(index, 0, last)
	_apply_controller_focus_visual()
	_announce_controller_focus()


func _apply_controller_focus_visual() -> void:
	for i in _slots.size():
		_slots[i].set_controller_focused(i == _controller_focus)
		_slots[i].set_drop_target(_controller_held >= 0 and i == _controller_focus and i != _controller_held)


func _announce_controller_focus() -> void:
	_hide_inspect()
	if _controller_focus < 0:
		EventBus.toggle_tooltip.emit(false, "", Rect2())
		return
	AudioManager.play_ui_hover()
	if _controller_focus == _sell_index():
		var sell_panel := _find_sell_panel()
		var held := ChefManager.get_chef(_controller_held)
		if sell_panel != null and held != null:
			EventBus.toggle_tooltip.emit(
				true,
				"Sell %s for %s" % [held.name, MerchantShopStyling.format_price(held.get_sell_value())],
				sell_panel.get_global_rect()
			)
		return
	EventBus.toggle_tooltip.emit(false, "", Rect2())
	if _controller_held < 0:
		_show_inspect(_controller_focus)

#endregion --- Controller ---


## Controller focus index of the Sell target, one past the last hex.
func _sell_index() -> int:
	return _slots.size()


func _find_sell_panel() -> CardSellPanel:
	return get_tree().get_first_node_in_group("card_sell_panel") as CardSellPanel


func _find_tile_map() -> HexTileMap:
	# hex_map_group is also on a child TileMapLayer. Skip anything that is not the map.
	for node in get_tree().get_nodes_in_group("hex_map_group"):
		var tile_map := node as HexTileMap
		if tile_map != null:
			return tile_map
	return null
