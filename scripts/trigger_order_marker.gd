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

# Bob distance in pixels. Size and rest placement come from the scene NumberGroup offsets.
const FLOAT_AMPLITUDE := 4.0
const FLOAT_HALF_CYCLE_MIN := 1.15

var _float_tween: Tween
# Authored NumberGroup offsets from the scene. Float animation adds Y on top of these.
var _group_offset_left: float = 0.0
var _group_offset_right: float = 0.0
var _group_offset_top: float = 0.0
var _group_offset_bottom: float = 0.0
var _cached_group_rect: bool = false


func setup(order: int, _is_start: bool, _is_end: bool) -> void:
	_ensure_nodes()
	_cache_authored_group_rect()
	_order = order
	size = Hex.HEX_TILE_SIZE
	custom_minimum_size = Hex.HEX_TILE_SIZE
	order_label.text = str(order)
	_apply_group_y_offset(0.0)
	_apply_visual_state()


func set_number_backdrop_visible(show_backdrop: bool) -> void:
	if _show_number_backdrop == show_backdrop:
		return
	_show_number_backdrop = show_backdrop
	_apply_visual_state()


func set_number_visible(number_shown: bool) -> void:
	if _number_visible == number_shown:
		return
	_number_visible = number_shown
	_apply_visual_state()


func _apply_visual_state() -> void:
	_ensure_nodes()
	var show_backdrop := _number_visible and _show_number_backdrop
	number_backdrop.visible = show_backdrop
	number_group.visible = _number_visible
	order_label.visible = _number_visible
	_sync_float_state()


func _sync_float_state() -> void:
	# Hover refreshes revisit visible markers often. Only start float when it is not already running.
	if _number_visible:
		if _float_tween == null or not _float_tween.is_valid():
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
	_apply_group_y_offset(offset)


func _cache_authored_group_rect() -> void:
	if _cached_group_rect or number_group == null:
		return
	# Keep designer size from trigger_order_marker.tscn. Do not replace it with script constants.
	_group_offset_left = number_group.offset_left
	_group_offset_right = number_group.offset_right
	_group_offset_top = number_group.offset_top
	_group_offset_bottom = number_group.offset_bottom
	_cached_group_rect = true


func _apply_group_y_offset(y: float) -> void:
	if number_group == null:
		return
	_cache_authored_group_rect()
	number_group.offset_left = _group_offset_left
	number_group.offset_right = _group_offset_right
	number_group.offset_top = _group_offset_top + y
	number_group.offset_bottom = _group_offset_bottom + y


func _ensure_nodes() -> void:
	if number_group == null:
		number_group = $NumberGroup
	if number_backdrop == null:
		number_backdrop = $NumberGroup/NumberBackdrop
	if order_label == null:
		order_label = $NumberGroup/OrderLabel
