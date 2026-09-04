extends Node

signal input_mode_changed(using_gamepad: bool)

enum InputMode {
	KEYBOARD_MOUSE,
	GAMEPAD,
}

const NAV_DEADZONE := 0.35
const NAV_REPEAT_DELAY := 0.14

const ACTION_GAMEPAD_CONFIRM := "gamepad_confirm"
const ACTION_GAMEPAD_BACK := "gamepad_back"
const ACTION_NAV_LEFT := "nav_left"
const ACTION_NAV_RIGHT := "nav_right"
const ACTION_NAV_UP := "nav_up"
const ACTION_NAV_DOWN := "nav_down"
const ACTION_CHARACTER_LAYOUT_PREV := "character_layout_prev"
const ACTION_CHARACTER_LAYOUT_NEXT := "character_layout_next"
const ACTION_UI_CYCLE := "gamepad_ui_cycle"

var input_mode: InputMode = InputMode.KEYBOARD_MOUSE
var _nav_cooldown := 0.0


func _ready() -> void:
	_register_controller_actions()


func _input(event: InputEvent) -> void:
	if _is_gamepad_event(event):
		_set_input_mode(InputMode.GAMEPAD)
	elif _is_keyboard_mouse_event(event):
		_set_input_mode(InputMode.KEYBOARD_MOUSE)


func _process(delta: float) -> void:
	if _nav_cooldown > 0.0:
		_nav_cooldown = maxf(_nav_cooldown - delta, 0.0)


func is_using_gamepad() -> bool:
	return input_mode == InputMode.GAMEPAD


## Returns a cardinal direction after stick or D-pad input, with repeat throttling.
func consume_navigation_vector() -> Vector2:
	if _nav_cooldown > 0.0:
		return Vector2.ZERO
	var direction := Input.get_vector(ACTION_NAV_LEFT, ACTION_NAV_RIGHT, ACTION_NAV_UP, ACTION_NAV_DOWN)
	if direction.length() < NAV_DEADZONE:
		return Vector2.ZERO
	_nav_cooldown = NAV_REPEAT_DELAY
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	return Vector2(0.0, signf(direction.y))


func is_confirm_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed(ACTION_GAMEPAD_CONFIRM)


func is_back_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed(ACTION_GAMEPAD_BACK) or event.is_action_pressed("ui_cancel")


func is_ui_cycle_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed(ACTION_UI_CYCLE)


func _set_input_mode(mode: InputMode) -> void:
	if input_mode == mode:
		return
	input_mode = mode
	if mode == InputMode.GAMEPAD:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	input_mode_changed.emit(mode == InputMode.GAMEPAD)


func _is_gamepad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _is_keyboard_mouse_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	)


func _register_controller_actions() -> void:
	_ensure_action(ACTION_GAMEPAD_CONFIRM)
	_add_key(ACTION_GAMEPAD_CONFIRM, KEY_ENTER)
	_add_key(ACTION_GAMEPAD_CONFIRM, KEY_SPACE)
	_add_joy_button(ACTION_GAMEPAD_CONFIRM, JOY_BUTTON_A)

	_ensure_action(ACTION_GAMEPAD_BACK)
	_add_key(ACTION_GAMEPAD_BACK, KEY_ESCAPE)
	_add_joy_button(ACTION_GAMEPAD_BACK, JOY_BUTTON_B)

	_register_direction_action(ACTION_NAV_LEFT, KEY_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_register_direction_action(ACTION_NAV_RIGHT, KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_register_direction_action(ACTION_NAV_UP, KEY_UP, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_register_direction_action(ACTION_NAV_DOWN, KEY_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)

	# Pause from the Start button on common controllers.
	_add_joy_button("pause_game", JOY_BUTTON_START)

	# Character selection layout paging. LB goes back, RB goes forward.
	_ensure_action(ACTION_CHARACTER_LAYOUT_PREV, 0.5)
	_add_joy_button(ACTION_CHARACTER_LAYOUT_PREV, JOY_BUTTON_LEFT_SHOULDER)

	_ensure_action(ACTION_CHARACTER_LAYOUT_NEXT, 0.5)
	_add_joy_button(ACTION_CHARACTER_LAYOUT_NEXT, JOY_BUTTON_RIGHT_SHOULDER)

	_ensure_action(ACTION_UI_CYCLE)
	_add_key(ACTION_UI_CYCLE, KEY_TAB)
	_add_joy_button(ACTION_UI_CYCLE, JOY_BUTTON_Y)

	# Godot's built-in menu navigation reads ui_* actions, not gameplay nav actions.
	_register_direction_action("ui_left", KEY_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_register_direction_action("ui_right", KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_register_direction_action("ui_up", KEY_UP, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_register_direction_action("ui_down", KEY_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)

	_ensure_action("ui_accept")
	_add_key("ui_accept", KEY_ENTER)
	_add_key("ui_accept", KEY_SPACE)
	_add_joy_button("ui_accept", JOY_BUTTON_A)

	_ensure_action("ui_cancel")
	_add_key("ui_cancel", KEY_ESCAPE)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)


func _register_direction_action(
	action: String,
	keycode: Key,
	button: JoyButton,
	axis: JoyAxis,
	axis_value: float
) -> void:
	_ensure_action(action)
	_add_key(action, keycode)
	_add_joy_button(action, button)
	_add_joy_axis(action, axis, axis_value)


func _ensure_action(action: String, deadzone: float = NAV_DEADZONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _add_key(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	_add_unique_event(action, event)


func _add_joy_button(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_unique_event(action, event)


func _add_joy_axis(action: String, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_unique_event(action, event)


func _add_unique_event(action: String, event: InputEvent) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)
