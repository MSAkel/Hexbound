extends Node

## Controller support shared by every screen.
## - Registers the gamepad bindings at startup (see BINDINGS).
## - Tracks whether the player is on a gamepad or keyboard and mouse, and hides the cursor on a pad.
## - Menus join MENU_GROUP. A pad press with no focused control re-seats focus on the topmost menu,
##   and gameplay input stays off while any menu is active.
## - Draws a focus ring on focused controls that have no focus style of their own.
## - Scrolls the focused or topmost menu's ScrollContainer with the right stick.
## - Names buttons for prompts in the layout of the connected pad (Xbox, PlayStation, Nintendo).

signal input_mode_changed(using_gamepad: bool)
## The pad family changed, so prompts should be re-read.
signal prompts_changed

enum InputMode {
	KEYBOARD_MOUSE,
	GAMEPAD,
}

enum PadFamily {
	XBOX,
	PLAYSTATION,
	NINTENDO,
}

## Menus that hold GUI focus join this group. A member may define:
##   is_gamepad_menu_active() -> bool  (default: visible). Inactive menus are skipped and do not block gameplay.
##   focus_default() -> void           (default: first focusable descendant).
const MENU_GROUP := &"gamepad_menu"
## Controls that draw their own focused state set this meta to true so the ring skips them.
const OWN_FOCUS_VISUAL_META := &"own_focus_visual"

const ACTION_CONFIRM := &"pad_confirm"
const ACTION_BACK := &"pad_back"
const ACTION_SELL := &"pad_sell"
const ACTION_ALT := &"pad_alt"
const ACTION_PAGE_PREV := &"pad_page_prev"
const ACTION_PAGE_NEXT := &"pad_page_next"
const ACTION_LEFT := &"pad_left"
const ACTION_RIGHT := &"pad_right"
const ACTION_UP := &"pad_up"
const ACTION_DOWN := &"pad_down"
const ACTION_SCROLL_UP := &"pad_scroll_up"
const ACTION_SCROLL_DOWN := &"pad_scroll_down"
const ACTION_PAUSE := &"pause_game"

## Stick deadzone for the gameplay and menu direction actions.
const STICK_DEADZONE := 0.4
## Stick travel needed before a pad counts as the active device. Ignores drift on an idle pad.
const STICK_WAKE_THRESHOLD := 0.5
## Mouse travel in one event needed before the mouse takes over from a pad.
const MOUSE_WAKE_DISTANCE := 4.0
## Right-stick scroll speed in pixels per second at full tilt.
const SCROLL_SPEED := 1400.0

const FOCUS_RING_LAYER := 120
const FOCUS_RING_COLOR := Color("#ffd166")
const FOCUS_RING_WIDTH := 3.0
const FOCUS_RING_PADDING := 6.0

## action -> events. Keys are only added where they help keyboard menu use.
## Godot's ui_* actions already ship with keyboard events. The pad events are added to them here.
const BINDINGS := {
	&"ui_accept": [JOY_BUTTON_A],
	&"ui_cancel": [JOY_BUTTON_B],
	&"ui_left": [JOY_BUTTON_DPAD_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
	&"ui_right": [JOY_BUTTON_DPAD_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	&"ui_up": [JOY_BUTTON_DPAD_UP, [JOY_AXIS_LEFT_Y, -1.0]],
	&"ui_down": [JOY_BUTTON_DPAD_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
	ACTION_CONFIRM: [JOY_BUTTON_A],
	ACTION_BACK: [JOY_BUTTON_B],
	ACTION_SELL: [JOY_BUTTON_X],
	ACTION_ALT: [JOY_BUTTON_Y],
	ACTION_PAGE_PREV: [JOY_BUTTON_LEFT_SHOULDER, KEY_PAGEUP],
	ACTION_PAGE_NEXT: [JOY_BUTTON_RIGHT_SHOULDER, KEY_PAGEDOWN],
	ACTION_LEFT: [JOY_BUTTON_DPAD_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
	ACTION_RIGHT: [JOY_BUTTON_DPAD_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	ACTION_UP: [JOY_BUTTON_DPAD_UP, [JOY_AXIS_LEFT_Y, -1.0]],
	ACTION_DOWN: [JOY_BUTTON_DPAD_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
	ACTION_SCROLL_UP: [[JOY_AXIS_RIGHT_Y, -1.0]],
	ACTION_SCROLL_DOWN: [[JOY_AXIS_RIGHT_Y, 1.0]],
	ACTION_PAUSE: [JOY_BUTTON_START],
}

## Button names by family. Godot reports buttons by position, so A is always the bottom face button.
const BUTTON_NAMES := {
	PadFamily.XBOX: {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "View",
	},
	PadFamily.PLAYSTATION: {
		JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Share",
	},
	PadFamily.NINTENDO: {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
		JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "-",
	},
}

var input_mode: InputMode = InputMode.KEYBOARD_MOUSE
var pad_family: PadFamily = PadFamily.XBOX
## True when the last menu input came from a pad or the keyboard, so focus should be drawn.
var _focus_visible := false
var _scroll_remainder := 0.0
var _ring_layer: CanvasLayer
var _ring: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_bindings()
	_build_focus_ring()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# The window sees each event before any node does. Scene nodes run _input before autoloads,
	# so a node that consumes a click would otherwise hide the device switch from this script.
	get_tree().root.window_input.connect(_track_device)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		_set_pad_family(_family_for_device(pads[0]))


# Input holds the project's custom cursor texture until after the renderer shuts down,
# which leaks it at exit. Release it while the scene tree is still being torn down.
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


func _input(event: InputEvent) -> void:
	if _is_pad_wake_event(event) and _recover_focus_for(event):
		get_viewport().set_input_as_handled()


func _track_device(event: InputEvent) -> void:
	if _is_pad_wake_event(event):
		_set_pad_family(_family_for_device(event.device))
		_set_input_mode(InputMode.GAMEPAD)
		_focus_visible = true
	elif event is InputEventKey and event.pressed:
		_set_input_mode(InputMode.KEYBOARD_MOUSE)
		_focus_visible = true
	elif event is InputEventMouseButton and event.pressed:
		_set_input_mode(InputMode.KEYBOARD_MOUSE)
		_focus_visible = false
	elif event is InputEventMouseMotion \
			and (event as InputEventMouseMotion).relative.length() >= MOUSE_WAKE_DISTANCE:
		_set_input_mode(InputMode.KEYBOARD_MOUSE)
		_focus_visible = false


func _process(delta: float) -> void:
	_ring.queue_redraw()
	if is_using_gamepad():
		_scroll_with_right_stick(delta)


func is_using_gamepad() -> bool:
	return input_mode == InputMode.GAMEPAD


#region Prompts

## Name of the first pad button bound to action, in the connected pad's layout. Empty if none.
func get_button_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	var names: Dictionary = BUTTON_NAMES[pad_family]
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if button != null and names.has(button.button_index):
			return names[button.button_index]
	return ""


## Prompt chip text such as "[A]" for BBCode labels. Uses the keyboard wording when no pad is in use.
func format_prompt(action: StringName, label: String) -> String:
	var button := get_button_name(action)
	if button.is_empty():
		return label
	return "[b][color=#ffd166]%s[/color][/b] %s" % [button, label]

#endregion


#region Menus

## Topmost menu that currently wants focus, or null.
func get_active_menu() -> Control:
	var best: Control = null
	for node in get_tree().get_nodes_in_group(MENU_GROUP):
		var menu := node as Control
		if menu == null or not _is_menu_active(menu):
			continue
		if best == null or _draws_above(menu, best):
			best = menu
	return best


func has_active_menu() -> bool:
	return get_active_menu() != null


## Re-seats focus on the topmost active menu when nothing usable holds it.
## True when focus was moved.
func recover_focus() -> bool:
	if _has_usable_focus():
		return false
	var menu := get_active_menu()
	if menu == null:
		return false
	if menu.has_method("focus_default"):
		menu.call("focus_default")
	else:
		MenuFocus.grab_first(menu)
	return _has_usable_focus()


func _recover_focus_for(event: InputEvent) -> bool:
	# Only menu presses re-seat focus. The press that lands focus is swallowed so it does not also act.
	for action: StringName in [&"ui_accept", &"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		if event.is_action_pressed(action):
			return recover_focus()
	return false


func _is_menu_active(menu: Control) -> bool:
	if not is_instance_valid(menu) or not menu.is_visible_in_tree():
		return false
	if menu.has_method("is_gamepad_menu_active"):
		return bool(menu.call("is_gamepad_menu_active"))
	return true


func _has_usable_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner != null and owner.is_visible_in_tree()


## Higher canvas layer wins, then later tree order.
func _draws_above(a: Control, b: Control) -> bool:
	var layer_a := _canvas_layer_of(a)
	var layer_b := _canvas_layer_of(b)
	if layer_a != layer_b:
		return layer_a > layer_b
	return a.is_greater_than(b)


func _canvas_layer_of(node: Node) -> int:
	var current := node.get_parent()
	while current != null:
		if current is CanvasLayer:
			return (current as CanvasLayer).layer
		current = current.get_parent()
	return 0

#endregion


#region Mode

func _set_input_mode(mode: InputMode) -> void:
	if input_mode == mode:
		return
	input_mode = mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if mode == InputMode.GAMEPAD else Input.MOUSE_MODE_VISIBLE
	input_mode_changed.emit(mode == InputMode.GAMEPAD)
	if mode == InputMode.GAMEPAD:
		recover_focus.call_deferred()


func _is_pad_wake_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= STICK_WAKE_THRESHOLD
	return false


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_set_pad_family(_family_for_device(device))
		return
	# With no pad left, bring the cursor back.
	if Input.get_connected_joypads().is_empty():
		_set_input_mode(InputMode.KEYBOARD_MOUSE)


func _family_for_device(device: int) -> PadFamily:
	var pad_name := Input.get_joy_name(device).to_lower()
	for hint in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if pad_name.contains(hint):
			return PadFamily.PLAYSTATION
	for hint in ["nintendo", "switch", "joy-con", "pro controller"]:
		if pad_name.contains(hint):
			return PadFamily.NINTENDO
	return PadFamily.XBOX


func _set_pad_family(family: PadFamily) -> void:
	if pad_family == family:
		return
	pad_family = family
	prompts_changed.emit()

#endregion


#region Scrolling

func _scroll_with_right_stick(delta: float) -> void:
	var axis := Input.get_axis(ACTION_SCROLL_UP, ACTION_SCROLL_DOWN)
	if is_zero_approx(axis):
		_scroll_remainder = 0.0
		return
	var scroll := _find_scroll_target()
	if scroll == null:
		return
	_scroll_remainder += axis * SCROLL_SPEED * delta
	var step := int(_scroll_remainder)
	if step == 0:
		return
	_scroll_remainder -= step
	scroll.scroll_vertical += step


## The ScrollContainer around the focused control, else the first scrollable one in the active menu.
func _find_scroll_target() -> ScrollContainer:
	var node: Node = get_viewport().gui_get_focus_owner()
	while node != null:
		if node is ScrollContainer and _can_scroll(node as ScrollContainer):
			return node as ScrollContainer
		node = node.get_parent()
	var menu := get_active_menu()
	return _find_scrollable(menu) if menu != null else null


func _find_scrollable(node: Node) -> ScrollContainer:
	if node is ScrollContainer and _can_scroll(node as ScrollContainer):
		return node as ScrollContainer
	for child in node.get_children():
		var found := _find_scrollable(child)
		if found != null:
			return found
	return null


func _can_scroll(scroll: ScrollContainer) -> bool:
	if not scroll.is_visible_in_tree():
		return false
	var bar := scroll.get_v_scroll_bar()
	return bar != null and bar.max_value - bar.page > 0.5

#endregion


#region Focus ring

func _build_focus_ring() -> void:
	_ring_layer = CanvasLayer.new()
	_ring_layer.name = "FocusRingLayer"
	_ring_layer.layer = FOCUS_RING_LAYER
	add_child(_ring_layer)
	_ring = Control.new()
	_ring.name = "FocusRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_focus_ring)
	_ring_layer.add_child(_ring)


func _draw_focus_ring() -> void:
	if not _focus_visible:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not owner.is_visible_in_tree() or not _wants_ring(owner):
		return
	var xform := owner.get_global_transform_with_canvas()
	var rect := Rect2(xform * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [Vector2(owner.size.x, 0.0), Vector2(0.0, owner.size.y), owner.size]:
		rect = rect.expand(xform * corner)
	rect = rect.grow(FOCUS_RING_PADDING)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 180.0)
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(FOCUS_RING_COLOR, pulse)
	style.set_border_width_all(int(FOCUS_RING_WIDTH))
	style.set_corner_radius_all(8)
	_ring.draw_style_box(style, rect)


## Text fields and buttons with a drawn focus box show focus themselves. Everything else gets the ring.
## The theme's Button focus style reuses the hover art, and many scenes blank it, so it does not count.
func _wants_ring(control: Control) -> bool:
	if bool(control.get_meta(OWN_FOCUS_VISUAL_META, false)) or control is LineEdit:
		return false
	if control is Button:
		return not control.get_theme_stylebox(&"focus") is StyleBoxFlat
	return true

#endregion


#region Bindings

func _register_bindings() -> void:
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, STICK_DEADZONE)
		else:
			InputMap.action_set_deadzone(action, STICK_DEADZONE)
		for binding in BINDINGS[action]:
			_add_unique_event(action, _make_event(binding))


func _make_event(binding: Variant) -> InputEvent:
	if binding is Array:
		var motion := InputEventJoypadMotion.new()
		motion.axis = binding[0]
		motion.axis_value = binding[1]
		return motion
	# Key codes are far above the joypad button range.
	if int(binding) >= KEY_SPECIAL:
		var key := InputEventKey.new()
		key.physical_keycode = binding
		return key
	var button := InputEventJoypadButton.new()
	button.button_index = binding
	return button


func _add_unique_event(action: StringName, event: InputEvent) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)

#endregion
