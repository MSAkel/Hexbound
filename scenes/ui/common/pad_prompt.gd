class_name PadPrompt
extends Label

## Button name badge such as "LB" pinned beside a control. Shown only while a gamepad is in use.

enum Side {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM,
}

const GAP := 6.0
const FONT_SIZE := 18
const TEXT_COLOR := Color("#ffd166")

var action: StringName
## A Side value. Typed int: the static attach() builds this class, and GDScript cannot match
## its own enum type through that self-reference.
var side: int = Side.BOTTOM


## Adds a prompt for action to target. The prompt follows target's size and visibility.
## target must not be a Container, or it would lay the prompt out as one of its children.
static func attach(target: Control, prompt_action: StringName, prompt_side: int = Side.BOTTOM) -> PadPrompt:
	var prompt := PadPrompt.new()
	prompt.action = prompt_action
	prompt.side = prompt_side
	target.add_child(prompt)
	return prompt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("outline_size", 6)
	InputManager.input_mode_changed.connect(_refresh.unbind(1))
	InputManager.prompts_changed.connect(_refresh)
	resized.connect(_place)
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_place)
	_refresh()


func _refresh() -> void:
	text = InputManager.get_button_name(action)
	visible = InputManager.is_using_gamepad() and not text.is_empty()
	reset_size()
	_place()


func _place() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var host := parent_control.size
	match side:
		Side.LEFT:
			position = Vector2(-size.x - GAP, (host.y - size.y) * 0.5)
		Side.RIGHT:
			position = Vector2(host.x + GAP, (host.y - size.y) * 0.5)
		Side.TOP:
			position = Vector2((host.x - size.x) * 0.5, -size.y - GAP)
		Side.BOTTOM:
			position = Vector2((host.x - size.x) * 0.5, host.y + GAP)
