extends Node

enum Context {
	HAND,
	MAP,
	CONDIMENTS,
	LAYOUT_TOGGLES,
}

@onready var hand: Hand = $"../MainUI/CardsHand/Hand"
@onready var tile_map: HexTileMap = $"../HexTileMap"
@onready var condiment_belt: CondimentBelt = $"../MainUI/CondimentBelt"
@onready var layouts_container: PanelContainer = (
	$"../MainUI/RunInfoUI/RightContainer/VBoxContainer/layoutsContainer"
)
@onready var pause_menu: Control = $"../MainUI/PauseMenu"
@onready var game_over_screen: Control = $"../MainUI/GameOverScreen"
@onready var victory_screen: Control = $"../MainUI/VictoryScreen"
@onready var settings_container: Control = $"../MainUI/SettingsContainer"
@onready var merchant: Control = $"../MainUI/Merchant"
@onready var rune_selection_ui: Control = $"../MainUI/RuneSelectionUI"
@onready var round_complete_screen: Control = $"../MainUI/RoundCompleteScreen"

var _context := Context.HAND
var _placement_handler: CardPlacementHandler


func _ready() -> void:
	call_deferred("_bind_placement_handler")
	EventBus.turn_started.connect(_on_turn_started)
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	EventBus.condiment_targeting_changed.connect(_on_condiment_targeting_changed)


func _bind_placement_handler() -> void:
	if tile_map != null and tile_map.card_placement_handler != null:
		_placement_handler = tile_map.card_placement_handler


func _process(_delta: float) -> void:
	if not InputManager.is_using_gamepad():
		return
	if not _can_handle_gameplay_input():
		return
	var nav := InputManager.consume_navigation_vector()
	if nav == Vector2.ZERO:
		return
	if _is_card_selected() or CondimentManager.is_targeting():
		_move_map_focus(nav)
		return
	match _context:
		Context.HAND:
			if nav.x < 0.0:
				hand.move_controller_focus(-1)
			elif nav.x > 0.0:
				hand.move_controller_focus(1)
		Context.MAP:
			tile_map.move_gamepad_focus(nav)
		Context.CONDIMENTS:
			var direction := 0
			if nav.y < 0.0 or nav.x < 0.0:
				direction = -1
			elif nav.y > 0.0 or nav.x > 0.0:
				direction = 1
			if direction != 0:
				condiment_belt.move_controller_focus(direction)
		Context.LAYOUT_TOGGLES:
			if layouts_container == null:
				return
			if nav.x < 0.0:
				layouts_container.move_controller_focus(-1)
			elif nav.x > 0.0:
				layouts_container.move_controller_focus(1)


func _unhandled_input(event: InputEvent) -> void:
	if not InputManager.is_using_gamepad():
		return
	if not _can_handle_gameplay_input():
		return

	if InputManager.is_ui_cycle_pressed(event):
		_cycle_ui_context()
		get_viewport().set_input_as_handled()
		return

	if InputManager.is_confirm_pressed(event):
		_handle_confirm()
		get_viewport().set_input_as_handled()
		return

	if InputManager.is_back_pressed(event):
		_handle_back()
		get_viewport().set_input_as_handled()


func _handle_confirm() -> void:
	if CondimentManager.is_targeting():
		CondimentManager.try_apply_to_gamepad_focus_hex()
		return

	if _is_card_selected():
		if _placement_handler != null:
			_placement_handler.try_place_from_gamepad()
		return

	match _context:
		Context.HAND:
			var card := hand.get_controller_focused_card()
			if card == null:
				hand.ensure_controller_focus()
				card = hand.get_controller_focused_card()
			if card == null:
				return
			_begin_placement(card)
		Context.MAP:
			_inspect_focused_tile()
		Context.CONDIMENTS:
			condiment_belt.activate_controller_focused_slot()
		Context.LAYOUT_TOGGLES:
			if layouts_container != null:
				layouts_container.toggle_controller_focused_layout()


func _handle_back() -> void:
	if CondimentManager.is_targeting():
		CondimentManager.cancel_targeting()
		_context = Context.CONDIMENTS
		_apply_active_context()
		return
	if _is_card_selected():
		if _placement_handler != null:
			_placement_handler.cancel_gamepad_placement()
		return
	_context = Context.HAND
	_apply_active_context()


func _begin_placement(card: CardUI) -> void:
	if _placement_handler == null:
		_bind_placement_handler()
	if _placement_handler == null:
		return
	tile_map.ensure_gamepad_focus()
	_placement_handler.begin_gamepad_placement(card)
	_context = Context.MAP
	_clear_non_map_context_highlights()


func _move_map_focus(direction: Vector2) -> void:
	tile_map.move_gamepad_focus(direction)
	if _placement_handler != null:
		_placement_handler.refresh_gamepad_preview()


func _inspect_focused_tile() -> void:
	var coords := tile_map.get_gamepad_focus_cell()
	if coords == Vector2i(-1, -1):
		return
	if tile_map.hover_ui == null:
		return
	if not tile_map.is_in_map(coords) or not tile_map.is_tile_interactable(coords):
		tile_map.hover_ui.hide_tile_panel()
		return
	var hex: Hex = tile_map.map_data.get(coords)
	if hex == null or hex.active_tile_card == null:
		tile_map.hover_ui.hide_tile_panel()
		return
	tile_map.hover_ui.update_tile_panel_hover(coords, true)


func _cycle_ui_context() -> void:
	if _is_card_selected() or CondimentManager.is_targeting():
		return
	_context = (_context + 1) % Context.size()
	_apply_active_context()
	AudioManager.play_ui_hover()


func _apply_active_context() -> void:
	_clear_all_context_highlights()
	match _context:
		Context.HAND:
			hand.ensure_controller_focus()
		Context.MAP:
			tile_map.ensure_gamepad_focus()
		Context.CONDIMENTS:
			condiment_belt.ensure_controller_focus()
		Context.LAYOUT_TOGGLES:
			if layouts_container != null:
				layouts_container.ensure_controller_focus()


func _clear_all_context_highlights() -> void:
	hand.clear_controller_focus()
	tile_map.clear_gamepad_focus()
	condiment_belt.clear_controller_focus()
	if layouts_container != null:
		layouts_container.clear_controller_focus()


func _clear_non_map_context_highlights() -> void:
	hand.clear_controller_focus()
	condiment_belt.clear_controller_focus()
	if layouts_container != null:
		layouts_container.clear_controller_focus()


func _on_condiment_targeting_changed(_slot_index: int) -> void:
	if not InputManager.is_using_gamepad():
		return
	if CondimentManager.is_targeting():
		_context = Context.MAP
		_clear_non_map_context_highlights()
		tile_map.ensure_gamepad_focus()
	elif _context == Context.MAP and not _is_card_selected():
		_context = Context.CONDIMENTS
		_apply_active_context()


func _is_card_selected() -> bool:
	return _placement_handler != null and _placement_handler.is_card_selected


func _can_handle_gameplay_input() -> bool:
	if get_tree().paused:
		return false
	if GameManager.is_processing_turn:
		return false
	if hand == null or tile_map == null:
		return false
	if hand.is_awaiting_intro() or hand.is_hand_hidden():
		return false
	if _is_control_visible(pause_menu):
		return false
	if _is_control_visible(settings_container):
		return false
	if _is_control_visible(game_over_screen):
		return false
	if _is_control_visible(victory_screen):
		return false
	if _is_control_visible(merchant):
		return false
	if _is_control_visible(rune_selection_ui):
		return false
	if _is_control_visible(round_complete_screen):
		return false
	return true


func _is_control_visible(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree()


func _on_turn_started() -> void:
	_context = Context.HAND
	if InputManager.is_using_gamepad():
		call_deferred("_focus_hand_after_turn")


func _on_input_mode_changed(using_gamepad: bool) -> void:
	if using_gamepad:
		_context = Context.HAND if not _is_card_selected() else Context.MAP
		_apply_active_context()
	else:
		_clear_all_context_highlights()
		if _placement_handler != null:
			_placement_handler.switch_to_mouse_preview()


func _focus_hand_after_turn() -> void:
	if not InputManager.is_using_gamepad():
		return
	_context = Context.HAND
	_apply_active_context()
