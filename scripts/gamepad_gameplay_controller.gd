extends Node

## Routes in-run controller input across hand, map, condiments, and layout toggles.

enum Context {
	HAND,
	MAP,
	CONDIMENTS,
	LAYOUT_TOGGLES,
}

@onready var hand: Hand = $"../MainUI/CardsHand/Hand"
@onready var tile_map: HexTileMap = $"../HexTileMap"
@onready var condiment_belt: CondimentBelt = $"../MainUI/CondimentBelt"
@onready var layouts_container: LayoutsContainer = (
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
var _blocking_overlays: Array[Control] = []


func _ready() -> void:
	_blocking_overlays = [
		pause_menu,
		settings_container,
		game_over_screen,
		victory_screen,
		merchant,
		rune_selection_ui,
		round_complete_screen,
	]
	call_deferred("_bind_placement_handler")
	EventBus.turn_started.connect(_on_turn_started)
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	EventBus.condiment_targeting_changed.connect(_on_condiment_targeting_changed)


func _bind_placement_handler() -> void:
	if tile_map != null:
		_placement_handler = tile_map.card_placement_handler


func _process(_delta: float) -> void:
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
			_step_controller_focus(hand, int(signf(nav.x)))
		Context.MAP:
			tile_map.move_gamepad_focus(nav)
		Context.CONDIMENTS:
			# Belt is vertical, but left/right still steps between slots.
			_step_controller_focus(condiment_belt, _any_axis_step(nav))
		Context.LAYOUT_TOGGLES:
			_step_controller_focus(layouts_container, int(signf(nav.x)))


func _unhandled_input(event: InputEvent) -> void:
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
			if card != null:
				_begin_placement(card)
		Context.MAP:
			tile_map.inspect_gamepad_focus_tile()
		Context.CONDIMENTS:
			condiment_belt.activate_controller_focused_slot()
		Context.LAYOUT_TOGGLES:
			if layouts_container != null:
				layouts_container.toggle_controller_focused_layout()


func _handle_back() -> void:
	if CondimentManager.is_targeting():
		CondimentManager.cancel_targeting()
		_set_context(Context.CONDIMENTS)
		return
	if _is_card_selected():
		if _placement_handler != null:
			_placement_handler.cancel_gamepad_placement()
		return
	_set_context(Context.HAND)


func _begin_placement(card: CardUI) -> void:
	if _placement_handler == null:
		_bind_placement_handler()
	if _placement_handler == null:
		return
	tile_map.ensure_gamepad_focus()
	_placement_handler.begin_gamepad_placement(card)
	_context = Context.MAP
	_clear_context_highlights(true)


func _move_map_focus(direction: Vector2) -> void:
	tile_map.move_gamepad_focus(direction)
	if _placement_handler != null:
		_placement_handler.refresh_gamepad_preview()


func _cycle_ui_context() -> void:
	if _is_card_selected() or CondimentManager.is_targeting():
		return
	var next := (_context + 1) % Context.size()
	# Skip layout toggles when the run-info node is missing from this scene.
	if next == Context.LAYOUT_TOGGLES and layouts_container == null:
		next = Context.HAND
	_set_context(next)
	AudioManager.play_ui_hover()


func _set_context(context: Context) -> void:
	_context = context
	if InputManager.is_using_gamepad():
		_apply_active_context()


func _apply_active_context() -> void:
	if not InputManager.is_using_gamepad():
		return
	_clear_context_highlights(false)
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


func _clear_context_highlights(keep_map: bool) -> void:
	hand.clear_controller_focus()
	if not keep_map:
		tile_map.clear_gamepad_focus()
	condiment_belt.clear_controller_focus()
	if layouts_container != null:
		layouts_container.clear_controller_focus()


func _on_condiment_targeting_changed(_slot_index: int) -> void:
	if not InputManager.is_using_gamepad():
		return
	if CondimentManager.is_targeting():
		_context = Context.MAP
		_clear_context_highlights(true)
		tile_map.ensure_gamepad_focus()
	elif _context == Context.MAP and not _is_card_selected():
		_set_context(Context.CONDIMENTS)


func _is_card_selected() -> bool:
	return _placement_handler != null and _placement_handler.is_card_selected


func _can_handle_gameplay_input() -> bool:
	if not InputManager.is_using_gamepad():
		return false
	if get_tree().paused or GameManager.is_processing_turn:
		return false
	if hand == null or tile_map == null:
		return false
	if hand.is_awaiting_intro() or hand.is_hand_hidden():
		return false
	for overlay in _blocking_overlays:
		if is_instance_valid(overlay) and overlay.is_visible_in_tree():
			return false
	return true


func _on_turn_started() -> void:
	_context = Context.HAND
	if InputManager.is_using_gamepad():
		call_deferred("_apply_active_context")


func _on_input_mode_changed(using_gamepad: bool) -> void:
	if using_gamepad:
		_context = Context.MAP if _is_card_selected() else Context.HAND
		_apply_active_context()
		return
	_clear_context_highlights(false)
	if _placement_handler != null:
		_placement_handler.switch_to_mouse_preview()


func _step_controller_focus(target: Object, step: int) -> void:
	if target == null or step == 0:
		return
	target.move_controller_focus(step)


func _any_axis_step(nav: Vector2) -> int:
	if nav.x < 0.0 or nav.y < 0.0:
		return -1
	if nav.x > 0.0 or nav.y > 0.0:
		return 1
	return 0
