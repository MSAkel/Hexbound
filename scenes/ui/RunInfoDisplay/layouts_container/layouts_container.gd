extends PanelContainer

@onready var tile_cards_layout: TextureButton = $HBoxContainer/TileCardsLayout
@onready var trigger_order_layout: TextureButton = $HBoxContainer/TriggerOrderLayout
@onready var segment_links_layout: TextureButton = $HBoxContainer/SegmentLinksLayout

const CONTROLLER_FOCUS_MODULATE := Color(1.08, 1.05, 0.92, 1.0)

var _layout_buttons: Array[TextureButton] = []
var _controller_focus_index := -1


func _ready() -> void:
	# Click-to-toggle only. Controller focus uses a custom highlight instead of Tab stops.
	tile_cards_layout.focus_mode = Control.FOCUS_NONE
	trigger_order_layout.focus_mode = Control.FOCUS_NONE
	segment_links_layout.focus_mode = Control.FOCUS_NONE
	_layout_buttons = [tile_cards_layout, trigger_order_layout, segment_links_layout]
	_emit_overlay_state()


func _on_tile_cards_layout_toggled(_toggled_on: bool) -> void:
	_emit_overlay_state()


func _on_trigger_order_layout_toggled(_toggled_on: bool) -> void:
	_emit_overlay_state()


func _on_segment_links_layout_toggled(_toggled_on: bool) -> void:
	_emit_overlay_state()


func _emit_overlay_state() -> void:
	EventBus.map_display_overlays_changed.emit(
		tile_cards_layout.button_pressed,
		trigger_order_layout.button_pressed,
		segment_links_layout.button_pressed
	)


func _on_tile_cards_layout_mouse_entered() -> void:
	var tooltip := "Show cards"
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())


func _on_tile_cards_layout_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_trigger_order_layout_mouse_entered() -> void:
	var tooltip := "Show %s" % FeastDisplay.FIRE_ORDER.to_lower()
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())


func _on_trigger_order_layout_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_segment_links_layout_mouse_entered() -> void:
	var tooltip := "Show %s links" % FeastDisplay.COURSE.to_lower()
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())


func _on_segment_links_layout_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func ensure_controller_focus() -> void:
	if _layout_buttons.is_empty():
		return
	if _controller_focus_index < 0:
		_controller_focus_index = 0
	_apply_controller_focus_visual()


func clear_controller_focus() -> void:
	_controller_focus_index = -1
	_apply_controller_focus_visual()
	EventBus.toggle_tooltip.emit(false, "")


func move_controller_focus(direction: int) -> void:
	if _layout_buttons.is_empty():
		return
	if _controller_focus_index < 0:
		_controller_focus_index = 0
	else:
		_controller_focus_index = clampi(
			_controller_focus_index + direction,
			0,
			_layout_buttons.size() - 1
		)
	_apply_controller_focus_visual()


func toggle_controller_focused_layout() -> void:
	if _controller_focus_index < 0 or _controller_focus_index >= _layout_buttons.size():
		return
	var button := _layout_buttons[_controller_focus_index]
	button.button_pressed = not button.button_pressed
	_emit_overlay_state()


func _apply_controller_focus_visual() -> void:
	for i in _layout_buttons.size():
		var button := _layout_buttons[i]
		button.modulate = CONTROLLER_FOCUS_MODULATE if i == _controller_focus_index else Color.WHITE
	if _controller_focus_index >= 0 and _controller_focus_index < _layout_buttons.size():
		_show_layout_tooltip(_layout_buttons[_controller_focus_index])


func _show_layout_tooltip(button: TextureButton) -> void:
	if button == tile_cards_layout:
		EventBus.toggle_tooltip.emit(true, "Show cards", button.get_global_rect())
	elif button == trigger_order_layout:
		EventBus.toggle_tooltip.emit(
			true,
			"Show %s" % FeastDisplay.FIRE_ORDER.to_lower(),
			button.get_global_rect()
		)
	elif button == segment_links_layout:
		EventBus.toggle_tooltip.emit(
			true,
			"Show %s links" % FeastDisplay.COURSE.to_lower(),
			button.get_global_rect()
		)
