class_name GamepadGameplayController
extends Node

## Plays a run from a gamepad. The player works one area at a time: the hand, the board,
## the condiment belt or the staff column.
## - LB and RB switch areas. The D-pad also steps out of an area's edge into its neighbor.
## - A acts on the focus, B backs out, X sells (press twice), Y shows the focused station's info.
## - Menus in InputManager.MENU_GROUP and click hints switch this off while they are up.
##   A board view opened from the shop or a pick hands the board, belt and staff back to it.
## A hint bar at the top of the screen lists what each button does right now.

enum Area {
	HAND,
	BOARD,
	CONDIMENTS,
	STAFF,
}

## LB and RB walk this order.
const AREA_ORDER: Array[Area] = [Area.HAND, Area.BOARD, Area.CONDIMENTS, Area.STAFF]

@onready var hand: Hand = $"../MainUI/CardsHand/Hand"
@onready var tile_map: HexTileMap = $"../HexTileMap"
@onready var condiment_belt: CondimentBelt = $"../MainUI/CondimentBelt"
@onready var staff_rail: StaffRail = $"../MainUI/StaffRail"
@onready var sell_panel: CardSellPanel = $"../MainUI/CardSellPanel"
@onready var tutorial_overlay: TutorialOverlay = $"../MainUI/TutorialOverlay"

var _area := Area.HAND
var _active := false
var _placement_handler: CardPlacementHandler
var _nav := NavRepeater.new()
## The first Sell press aims here and the second sells it. Empty when nothing is armed.
var _sell_armed: Dictionary = {}
var _station_info_shown := false
var _hint_bar: ControllerHintBar


func _ready() -> void:
	_hint_bar = ControllerHintBar.new()
	add_child(_hint_bar)
	_bind_placement_handler.call_deferred()
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.card_drag_ended.connect(_on_card_drag_ended)
	EventBus.condiment_targeting_changed.connect(_on_condiment_targeting_changed)


func _bind_placement_handler() -> void:
	if tile_map != null:
		_placement_handler = tile_map.card_placement_handler


func _process(delta: float) -> void:
	var can_play := _can_handle_gameplay_input()
	if can_play != _active:
		_set_active(can_play)
	if not _active:
		_hint_bar.hide_hints()
		return
	var step := _nav.poll(delta)
	if step != Vector2i.ZERO:
		_on_nav(step)
	_refresh_hints()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or event.is_echo():
		return
	if event.is_action_pressed(InputManager.ACTION_SELL):
		_handle_sell()
	elif event.is_action_pressed(InputManager.ACTION_CONFIRM):
		_disarm_sell()
		_handle_confirm()
	elif event.is_action_pressed(InputManager.ACTION_BACK):
		_handle_back()
	elif event.is_action_pressed(InputManager.ACTION_ALT):
		_disarm_sell()
		_toggle_station_info()
	elif event.is_action_pressed(InputManager.ACTION_PAGE_PREV):
		_cycle_area(-1)
	elif event.is_action_pressed(InputManager.ACTION_PAGE_NEXT):
		_cycle_area(1)
	else:
		return
	get_viewport().set_input_as_handled()


#region Activation

func _can_handle_gameplay_input() -> bool:
	if not InputManager.is_using_gamepad():
		return false
	if get_tree().paused or GameManager.is_processing_turn:
		return false
	if hand == null or tile_map == null or hand.is_awaiting_intro():
		return false
	if tutorial_overlay != null and tutorial_overlay.is_blocking_input():
		return false
	if InputManager.has_active_menu():
		return false
	return not hand.is_hand_hidden() or _board_view_overlay() != null


func _set_active(active: bool) -> void:
	_active = active
	_nav.absorb()
	_disarm_sell()
	_hide_station_info()
	if active:
		if _is_card_selected():
			# A mouse drag carried over to the pad. Aim it with the board focus from here on.
			_area = Area.BOARD
			_placement_handler.begin_gamepad_placement(_placement_handler.selected_card)
		elif not _is_area_available(_area):
			_area = _first_available_area()
		_apply_area()
		return
	staff_rail.cancel_controller_hold()
	var aiming := _is_card_selected() or CondimentManager.is_targeting()
	if not InputManager.is_using_gamepad():
		_clear_highlights_except(-1, false)
		if _placement_handler != null:
			_placement_handler.switch_to_mouse_preview()
		return
	# A card or condiment still being aimed keeps the board focus it is aimed with.
	_clear_highlights_except(-1, aiming)


## The shop, card pick or station pick whose board view is open, or null.
func _board_view_overlay() -> Control:
	for node in get_tree().get_nodes_in_group(InputManager.MENU_GROUP):
		if node.has_method("is_board_view_active") and bool(node.call("is_board_view_active")):
			return node as Control
	return null

#endregion


#region Areas

func _is_area_available(area: Area) -> bool:
	match area:
		Area.HAND:
			return not hand.is_hand_hidden()
		Area.STAFF:
			return staff_rail.is_shown()
		_:
			return true


func _first_available_area() -> Area:
	for area in AREA_ORDER:
		if _is_area_available(area):
			return area
	return Area.BOARD


func _cycle_area(step: int) -> void:
	_disarm_sell()
	if _is_aiming() or staff_rail.is_controller_holding():
		return
	var index := AREA_ORDER.find(_area)
	for _i in AREA_ORDER.size():
		index = posmod(index + step, AREA_ORDER.size())
		if _is_area_available(AREA_ORDER[index]):
			_set_area(AREA_ORDER[index])
			return


func _set_area(area: Area) -> void:
	if area == _area:
		return
	_area = area
	_hide_station_info()
	_apply_area()
	AudioManager.play_ui_hover()


## Clears every other area's focus, then seats focus in the current one.
func _apply_area() -> void:
	if not InputManager.is_using_gamepad():
		return
	_clear_highlights_except(_area, _is_aiming())
	match _area:
		Area.HAND:
			hand.ensure_controller_focus()
		Area.BOARD:
			tile_map.ensure_gamepad_focus()
		Area.CONDIMENTS:
			condiment_belt.ensure_controller_focus()
		Area.STAFF:
			staff_rail.ensure_controller_focus()


## keep is the area to leave alone, or -1 for none. keep_board keeps the board focus regardless.
func _clear_highlights_except(keep: int, keep_board: bool) -> void:
	if keep != Area.HAND:
		hand.clear_controller_focus()
	if keep != Area.BOARD and not keep_board:
		tile_map.clear_gamepad_focus()
	if keep != Area.CONDIMENTS:
		condiment_belt.clear_controller_focus()
	if keep != Area.STAFF:
		staff_rail.clear_controller_focus()

#endregion


#region Navigation

func _on_nav(step: Vector2i) -> void:
	_disarm_sell()
	_hide_station_info()
	if _is_aiming():
		_move_board_focus(step)
		return
	match _area:
		Area.HAND:
			if step.y < 0:
				_set_area(Area.BOARD)
			elif step.x != 0:
				hand.move_controller_focus(step.x)
		Area.BOARD:
			var before := tile_map.get_gamepad_focus_cell()
			tile_map.move_gamepad_focus(Vector2(step))
			if tile_map.get_gamepad_focus_cell() == before:
				_leave_board_edge(step)
		Area.CONDIMENTS:
			if step.x < 0:
				_set_area(Area.BOARD)
			elif step.y != 0:
				condiment_belt.move_controller_focus(step.y)
		Area.STAFF:
			if step.x > 0 and not staff_rail.is_controller_holding():
				_set_area(Area.BOARD)
			elif step.y != 0:
				staff_rail.move_controller_focus(step.y)


## Focus could not move further on the board. Cross into the area on that side.
func _leave_board_edge(step: Vector2i) -> void:
	var target := Area.BOARD
	if step.y > 0:
		target = Area.HAND
	elif step.x < 0:
		target = Area.STAFF
	elif step.x > 0:
		target = Area.CONDIMENTS
	if target != Area.BOARD and _is_area_available(target):
		_set_area(target)


func _move_board_focus(step: Vector2i) -> void:
	tile_map.move_gamepad_focus(Vector2(step))
	if _placement_handler != null:
		_placement_handler.refresh_gamepad_preview()

#endregion


#region Buttons

func _handle_confirm() -> void:
	if CondimentManager.is_targeting():
		CondimentManager.try_apply_to_gamepad_focus_hex()
		return
	if _is_card_selected():
		_placement_handler.try_place_from_gamepad()
		return
	match _area:
		Area.HAND:
			var card := hand.get_controller_focused_card()
			if card != null:
				_begin_placement(card)
		Area.BOARD:
			tile_map.inspect_gamepad_focus_tile()
		Area.CONDIMENTS:
			condiment_belt.activate_controller_focused_slot()
		Area.STAFF:
			staff_rail.activate_controller_focus()


func _handle_back() -> void:
	if not _sell_armed.is_empty():
		_disarm_sell()
		return
	if CondimentManager.is_targeting():
		CondimentManager.cancel_targeting()
		return
	if _is_card_selected():
		_placement_handler.cancel_gamepad_placement()
		return
	if _station_info_shown:
		_hide_station_info()
		return
	if _area == Area.STAFF and staff_rail.cancel_controller_hold():
		return
	if _area != Area.HAND and _is_area_available(Area.HAND):
		_set_area(Area.HAND)
		return
	var overlay := _board_view_overlay()
	if overlay != null:
		overlay.call("set_board_view", false)


func _begin_placement(card: CardUI) -> void:
	if _placement_handler == null:
		_bind_placement_handler()
	if _placement_handler == null:
		return
	_area = Area.BOARD
	_clear_highlights_except(Area.BOARD, true)
	tile_map.ensure_gamepad_focus()
	_placement_handler.begin_gamepad_placement(card)


func _toggle_station_info() -> void:
	if _station_info_shown:
		_hide_station_info()
		return
	if _area != Area.BOARD and not _is_aiming():
		return
	_station_info_shown = tile_map.show_station_info_at(tile_map.get_gamepad_focus_cell())


func _hide_station_info() -> void:
	if not _station_info_shown:
		return
	_station_info_shown = false
	EventBus.toggle_tooltip.emit(false, "", Rect2())

#endregion


#region Selling

## First press arms the sale and names the price. A second press on the same thing sells it.
func _handle_sell() -> void:
	_hide_station_info()
	var target := _sell_target()
	if target.is_empty():
		_disarm_sell()
		return
	if not _sell_armed.is_empty() and _sell_armed["item"] == target["item"]:
		_commit_sell(target)
		return
	_sell_armed = target
	AudioManager.play_ui_hover()
	EventBus.toggle_tooltip.emit(
		true,
		"Sell %s for %s?\nPress %s again to sell." % [
			target["name"],
			MerchantShopStyling.format_price(target["value"]),
			InputManager.get_button_name(InputManager.ACTION_SELL),
		],
		sell_panel.get_global_rect()
	)


## What Sell acts on right now: {kind, item, name, value}, or empty.
func _sell_target() -> Dictionary:
	if CondimentManager.is_targeting():
		return {}
	var card: CardUI = null
	if _is_card_selected():
		card = _placement_handler.selected_card
	elif _area == Area.HAND:
		card = hand.get_controller_focused_card()
	if card != null and card.card != null:
		return {"kind": Area.HAND, "item": card, "name": card.card.name, "value": CardSellPanel.SELL_VALUE}
	match _area:
		Area.CONDIMENTS:
			var slot := condiment_belt.get_controller_focus_index()
			var condiment: Condiment = CondimentManager.belt[slot] if slot >= 0 else null
			if condiment != null and CondimentManager.can_sell_now():
				return {
					"kind": Area.CONDIMENTS,
					"item": condiment,
					"name": condiment.display_name,
					"value": condiment.get_sell_value(),
				}
		Area.STAFF:
			var staff := StaffManager.get_staff(staff_rail.get_controller_sell_slot())
			if staff != null and StaffManager.can_rearrange():
				return {"kind": Area.STAFF, "item": staff, "name": staff.name, "value": staff.get_sell_value()}
	return {}


func _commit_sell(target: Dictionary) -> void:
	_disarm_sell()
	match target["kind"]:
		Area.HAND:
			_placement_handler.sell_card_from_gamepad(target["item"] as CardUI)
		Area.CONDIMENTS:
			condiment_belt.sell_controller_focused_slot()
		Area.STAFF:
			staff_rail.sell_controller_target()


func _disarm_sell() -> void:
	if _sell_armed.is_empty():
		return
	_sell_armed = {}
	EventBus.toggle_tooltip.emit(false, "", Rect2())

#endregion


#region Hints

func _refresh_hints() -> void:
	var hints := PackedStringArray()
	var area_name := _area_name()
	# In a board view the overlay takes Y to return, so Station info is not offered there.
	var board_view := _board_view_overlay() != null
	if not _sell_armed.is_empty():
		_add_hint(hints, InputManager.ACTION_SELL, "Confirm sell")
		_add_hint(hints, InputManager.ACTION_BACK, "Keep")
	elif CondimentManager.is_targeting():
		area_name = GameTerms.CONDIMENTS
		_add_hint(hints, InputManager.ACTION_CONFIRM, "Apply here")
		_add_hint(hints, InputManager.ACTION_BACK, "Cancel")
	elif _is_card_selected():
		area_name = "Placing"
		_add_hint(hints, InputManager.ACTION_CONFIRM, "Place")
		_add_hint(hints, InputManager.ACTION_SELL, "Sell")
		if not board_view:
			_add_hint(hints, InputManager.ACTION_ALT, "Station")
		_add_hint(hints, InputManager.ACTION_BACK, "Cancel")
	else:
		match _area:
			Area.HAND:
				_add_hint(hints, InputManager.ACTION_CONFIRM, "Pick up")
				_add_hint(hints, InputManager.ACTION_SELL, "Sell")
			Area.BOARD:
				if not board_view:
					_add_hint(hints, InputManager.ACTION_ALT, "Station info")
			Area.CONDIMENTS:
				_add_hint(hints, InputManager.ACTION_CONFIRM, "Use")
				_add_hint(hints, InputManager.ACTION_SELL, "Sell")
			Area.STAFF:
				if staff_rail.is_controller_holding():
					_add_hint(hints, InputManager.ACTION_CONFIRM, "Put here")
					_add_hint(hints, InputManager.ACTION_BACK, "Cancel")
				else:
					_add_hint(hints, InputManager.ACTION_CONFIRM, "Move")
				_add_hint(hints, InputManager.ACTION_SELL, "Sell")
		if not staff_rail.is_controller_holding():
			hints.append("[b][color=#ffd166]%s/%s[/color][/b] Area" % [
				InputManager.get_button_name(InputManager.ACTION_PAGE_PREV),
				InputManager.get_button_name(InputManager.ACTION_PAGE_NEXT),
			])
		if board_view:
			_add_hint(hints, InputManager.ACTION_ALT, "Return")
		else:
			_add_hint(hints, InputManager.ACTION_PAUSE, "Menu")
	_hint_bar.show_hints(area_name, hints, board_view)


func _add_hint(hints: PackedStringArray, action: StringName, label: String) -> void:
	hints.append(InputManager.format_prompt(action, label))


func _area_name() -> String:
	match _area:
		Area.HAND:
			return "Hand"
		Area.BOARD:
			return "Board"
		Area.CONDIMENTS:
			return GameTerms.CONDIMENTS
		_:
			return "Staff"

#endregion


#region Events

func _on_turn_started() -> void:
	_area = Area.HAND
	if _active:
		_apply_area.call_deferred()


## After a card is placed, sold or put back, focus returns to the hand for the next pick.
func _on_card_drag_ended(_card: CardUI, _outcome: int) -> void:
	if not InputManager.is_using_gamepad():
		return
	_area = Area.HAND if _is_area_available(Area.HAND) else Area.BOARD
	if _active:
		_apply_area.call_deferred()


func _on_condiment_targeting_changed(_slot_index: int) -> void:
	if not InputManager.is_using_gamepad():
		return
	if CondimentManager.is_targeting():
		_area = Area.BOARD
		_clear_highlights_except(Area.BOARD, true)
		tile_map.ensure_gamepad_focus()
	elif _area == Area.BOARD and not _is_card_selected():
		_area = Area.CONDIMENTS
		if _active:
			_apply_area()

#endregion


func _is_card_selected() -> bool:
	return _placement_handler != null and _placement_handler.is_card_selected


## A hand card or tile condiment is being aimed at the board.
func _is_aiming() -> bool:
	return _is_card_selected() or CondimentManager.is_targeting()
