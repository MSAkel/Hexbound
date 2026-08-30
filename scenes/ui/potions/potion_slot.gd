class_name PotionSlot
extends Control

## Square belt cell. Shows only the potion icon, or stays empty.

signal drag_started(slot_index: int)
signal remove_requested(slot_index: int)

const SLOT_SIZE := Vector2(80, 80)
const HOLD_SELECT_SEC := 0.18

@export var slot_index: int = 0

var potion: Potion = null
var targeting := false

var _well: PanelContainer
var _icon: TextureRect
var _menu: PopupMenu
var _lifted := false
var _hold_token := 0


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	# Scale hover from the center of the square, not the top-left corner.
	pivot_offset = SLOT_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_menu = PopupMenu.new()
	_menu.add_item("Remove", 0)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)
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
	if _icon == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_icon, "scale", Vector2(0.2, 0.2), 0.22)
	tween.parallel().tween_property(_icon, "modulate:a", 0.0, 0.22)
	await tween.finished
	_icon.scale = Vector2.ONE
	_icon.modulate.a = 1.0


func _build() -> void:
	_well = PanelContainer.new()
	_well.set_anchors_preset(Control.PRESET_FULL_RECT)
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_well)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.pivot_offset = Vector2(32.0, 32.0)
	_well.add_child(_icon)


func _well_style() -> StyleBoxFlat:
	# Same well as merchant shelf bottles so belt and shop read as one set.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("536044")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("F4D48A") if targeting else Color("F7E9C4")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	style.shadow_color = Color("00000040")
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _refresh() -> void:
	_well.add_theme_stylebox_override("panel", _well_style())
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
