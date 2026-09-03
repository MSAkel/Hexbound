class_name CondimentSlot
extends Control

## Square belt cell. Shows a grey placeholder when empty, or the condiment icon.
## Layout lives in condiment_slot.tscn.

signal drag_started(slot_index: int)
signal remove_requested(slot_index: int)

const SLOT_SIZE := Vector2(60, 60)
const HOLD_SELECT_SEC := 0.18
const DRAG_START_THRESHOLD_PX := 8.0
const EMPTY_ICON := preload("res://assets/icons/condiments/mayonnaise.png")
const EMPTY_ICON_TINT := Color(0.52, 0.52, 0.52, 0.45)

@export var slot_index: int = 0
@export var well_idle_style: StyleBoxFlat
@export var well_selected_style: StyleBoxFlat

@onready var _well: PanelContainer = %Well
@onready var _empty_icon: TextureRect = %EmptyIcon
@onready var _icon: TextureRect = %Icon
@onready var _menu: PopupMenu = %ContextMenu

var condiment: Condiment = null
var targeting := false

var _lifted := false
var _hold_token := 0
var _press_held := false
var _press_screen_pos := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	# Scale hover from the center of the square, not the top-left corner.
	pivot_offset = SLOT_SIZE * 0.5
	_empty_icon.texture = EMPTY_ICON
	_empty_icon.modulate = EMPTY_ICON_TINT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_refresh()


func set_condiment(new_condiment: Condiment) -> void:
	condiment = new_condiment
	_refresh()


func set_targeting(active: bool) -> void:
	targeting = active
	_refresh()


## Hide the slot icon while this condiment is being dragged.
func set_lifted(lifted: bool) -> void:
	_lifted = lifted
	_refresh()
	if lifted:
		EventBus.toggle_tooltip.emit(false, "", Rect2())


func play_consume_animation() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_icon, "scale", Vector2(0.2, 0.2), 0.22)
	tween.parallel().tween_property(_icon, "modulate:a", 0.0, 0.22)
	await tween.finished
	_icon.scale = Vector2.ONE
	_icon.modulate.a = 1.0


func _refresh() -> void:
	_well.add_theme_stylebox_override("panel", well_selected_style if targeting else well_idle_style)
	var filled := condiment != null
	_empty_icon.visible = not filled
	_icon.visible = filled and not _lifted
	if not filled:
		return
	_icon.texture = condiment.icon
	# Keep the authored flask colors. Do not tint with liquid_color.
	_icon.self_modulate = Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if condiment != null:
				_press_held = true
				_press_screen_pos = get_global_mouse_position()
				_begin_hold_drag()
			get_viewport().set_input_as_handled()
		else:
			_press_held = false
			_cancel_hold_drag()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and condiment != null and not _lifted:
		_press_held = false
		_cancel_hold_drag()
		_menu.position = Vector2i(get_global_mouse_position())
		_menu.popup()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _press_held or _lifted or condiment == null:
		return
	if event is InputEventMouseMotion:
		if get_global_mouse_position().distance_to(_press_screen_pos) < DRAG_START_THRESHOLD_PX:
			return
		_press_held = false
		_cancel_hold_drag()
		drag_started.emit(slot_index)
		get_viewport().set_input_as_handled()


func _begin_hold_drag() -> void:
	_hold_token += 1
	var token := _hold_token
	await get_tree().create_timer(HOLD_SELECT_SEC).timeout
	if token != _hold_token:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if _lifted or condiment == null:
		return
	drag_started.emit(slot_index)


func _cancel_hold_drag() -> void:
	_hold_token += 1


func _on_menu_id_pressed(id: int) -> void:
	if id == 0:
		remove_requested.emit(slot_index)


func _on_mouse_entered() -> void:
	if condiment == null or _lifted:
		return
	AudioManager.play_condiment_hover()
	EventBus.toggle_tooltip.emit(
		true,
		"%s\n%s" % [condiment.display_name, condiment.description],
		get_global_rect()
	)


func _on_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())
