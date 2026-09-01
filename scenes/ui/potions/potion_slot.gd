class_name PotionSlot
extends Control

## Square belt cell. Shows only the potion icon, or stays empty.
## Layout lives in potion_slot.tscn.

signal drag_started(slot_index: int)
signal remove_requested(slot_index: int)

const SLOT_SIZE := Vector2(80, 80)
const HOLD_SELECT_SEC := 0.18

@export var slot_index: int = 0
@export var well_idle_style: StyleBoxFlat
@export var well_selected_style: StyleBoxFlat

@onready var _well: PanelContainer = %Well
@onready var _icon: TextureRect = %Icon
@onready var _menu: PopupMenu = %ContextMenu

var potion: Potion = null
var targeting := false

var _lifted := false
var _hold_token := 0


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	# Scale hover from the center of the square, not the top-left corner.
	pivot_offset = SLOT_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_refresh()


func set_potion(new_potion: Potion) -> void:
	potion = new_potion
	_refresh()


func set_targeting(active: bool) -> void:
	targeting = active
	_refresh()


## Hide the slot icon while this potion is being dragged.
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
	var filled := potion != null
	_icon.visible = filled and not _lifted
	if not filled:
		return
	_icon.texture = potion.icon
	# Keep the authored flask colors. Do not tint with liquid_color.
	_icon.self_modulate = Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if potion != null:
				_begin_hold_drag()
			get_viewport().set_input_as_handled()
		else:
			_cancel_hold_drag()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and potion != null and not _lifted:
		_cancel_hold_drag()
		_menu.position = Vector2i(get_global_mouse_position())
		_menu.popup()
		get_viewport().set_input_as_handled()


func _begin_hold_drag() -> void:
	_hold_token += 1
	var token := _hold_token
	await get_tree().create_timer(HOLD_SELECT_SEC).timeout
	if token != _hold_token:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if _lifted or potion == null:
		return
	drag_started.emit(slot_index)


func _cancel_hold_drag() -> void:
	_hold_token += 1


func _on_menu_id_pressed(id: int) -> void:
	if id == 0:
		remove_requested.emit(slot_index)


func _on_mouse_entered() -> void:
	if potion == null or _lifted:
		return
	AudioManager.play_potion_hover()
	EventBus.toggle_tooltip.emit(
		true,
		"%s\n%s" % [potion.display_name, potion.description],
		get_global_rect()
	)


func _on_mouse_exited() -> void:
	if not _lifted:
		_cancel_hold_drag()
	EventBus.toggle_tooltip.emit(false, "", Rect2())
