class_name SellPrompt
extends Button

## The Sell button that opens next to a clicked Technique or condiment. Pressing it sells that item.
## StaffRail and CondimentBelt each hold one and decide what selling means. A press anywhere
## other than this button or the item it belongs to closes it. Look lives in sell_prompt.tscn.

signal sell_requested(index: int)

enum Placement { RIGHT, LEFT }

const LABEL_FORMAT := "Sell +%d"

## Space between the item and the button.
@export var gap := 10.0

## Slot of the item on show, or -1 while closed.
var _index := -1
## Screen rect of that item. A press there is left to the item, which toggles the button.
var _anchor := Rect2()


func _ready() -> void:
	hide()
	pressed.connect(_on_pressed)


## Opens the button beside anchor (a screen rect) with the item's sell value.
func show_for(index: int, anchor: Rect2, value: int, placement: Placement) -> void:
	_index = index
	_anchor = anchor
	text = LABEL_FORMAT % value
	show()
	reset_size()
	var x := anchor.end.x + gap if placement == Placement.RIGHT else anchor.position.x - size.x - gap
	global_position = Vector2(x, anchor.get_center().y - size.y * 0.5)


func close() -> void:
	_index = -1
	hide()


## Slot the button is open for, or -1.
func shown_index() -> int:
	return _index if visible else -1


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		close()
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var point := click.global_position
	if get_global_rect().has_point(point) or _anchor.has_point(point):
		return
	close()


func _on_pressed() -> void:
	var index := _index
	close()
	if index >= 0:
		sell_requested.emit(index)
