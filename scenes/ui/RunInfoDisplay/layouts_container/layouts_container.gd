extends PanelContainer

@onready var tile_cards_layout: TextureButton = $HBoxContainer/TileCardsLayout
@onready var trigger_order_layout: TextureButton = $HBoxContainer/TriggerOrderLayout
@onready var segment_links_layout: TextureButton = $HBoxContainer/SegmentLinksLayout


func _ready() -> void:
	# Click-to-toggle only. Do not keep keyboard focus or Tab stops working for map peek.
	tile_cards_layout.focus_mode = Control.FOCUS_NONE
	trigger_order_layout.focus_mode = Control.FOCUS_NONE
	segment_links_layout.focus_mode = Control.FOCUS_NONE
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
