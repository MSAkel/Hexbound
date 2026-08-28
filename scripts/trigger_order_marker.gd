class_name TriggerOrderMarker
extends Control

# One hex in the trigger-order overlay. Numbers float above cards and can pick up
# a compact backdrop when the tile is occupied.

@onready var number_group: Control = $NumberGroup
@onready var number_backdrop: Panel = $NumberGroup/NumberBackdrop
@onready var order_label: Label = $NumberGroup/OrderLabel

var _order: int = 0
var _show_number_backdrop: bool = false
var _number_visible: bool = false

# Pointy-top hex art reads a little high. Nudge the label toward the visual center.
const ORDER_LABEL_Y_OFFSET := -10.0
const NUMBER_GROUP_HALF_WIDTH := 56.0
const NUMBER_GROUP_HALF_HEIGHT := 46.0
const FLOAT_AMPLITUDE := 8.5
const FLOAT_HALF_CYCLE_MIN := 1.15

var _float_tween: Tween


func setup(order: int, _is_start: bool, _is_end: bool) -> void:
	_ensure_nodes()
	_order = order
	size = Hex.HEX_TILE_SIZE
	custom_minimum_size = Hex.HEX_TILE_SIZE
	order_label.text = str(order)
	_apply_group_y_offset(ORDER_LABEL_Y_OFFSET)
	_apply_visual_state()


func set_number_backdrop_visible(show_backdrop: bool) -> void:
	_show_number_backdrop = show_backdrop
	_apply_visual_state()


func set_number_visible(number_shown: bool) -> void:
	_number_visible = number_shown
	_apply_visual_state()


func _apply_visual_state() -> void:
	_ensure_nodes()
	var show_backdrop := _number_visible and _show_number_backdrop
	number_backdrop.visible = show_backdrop
	number_group.visible = _number_visible

	order_label.visible = _number_visible
	if _number_visible:
		_start_float()
	else:
		_stop_float()


func _start_float() -> void:
	_stop_float()
	_ensure_nodes()
	var half_cycle := FLOAT_HALF_CYCLE_MIN + fmod(float(_order) * 0.19, 0.55)
	_set_label_float_offset(0.0)
	_float_tween = create_tween().set_loops()
	_float_tween.tween_method(_set_label_float_offset, 0.0, -FLOAT_AMPLITUDE, half_cycle)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_method(_set_label_float_offset, -FLOAT_AMPLITUDE, FLOAT_AMPLITUDE, half_cycle * 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_method(_set_label_float_offset, FLOAT_AMPLITUDE, 0.0, half_cycle)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_float() -> void:
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
	_set_label_float_offset(0.0)


func _set_label_float_offset(offset: float) -> void:
	_apply_group_y_offset(ORDER_LABEL_Y_OFFSET + offset)


func _apply_group_y_offset(y: float) -> void:
	if number_group == null:
		return
	number_group.offset_left = -NUMBER_GROUP_HALF_WIDTH
	number_group.offset_right = NUMBER_GROUP_HALF_WIDTH
	number_group.offset_top = y - NUMBER_GROUP_HALF_HEIGHT
	number_group.offset_bottom = y + NUMBER_GROUP_HALF_HEIGHT


func _ensure_nodes() -> void:
	if number_group == null:
		number_group = $NumberGroup
	if number_backdrop == null:
		number_backdrop = $NumberGroup/NumberBackdrop
	if order_label == null:
		order_label = $NumberGroup/OrderLabel
