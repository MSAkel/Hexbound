extends PanelContainer

@onready var base_layout: TextureButton = $HBoxContainer/BaseLayout
@onready var tile_passives_layout: TextureButton = $HBoxContainer/TilePassivesLayout
@onready var order_segments_layout: TextureButton = $HBoxContainer/OrderSegmentsLayout

func _on_base_layout_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_passives_layout.button_pressed = false
		order_segments_layout.button_pressed = false
		EventBus.map_display_layout_changed.emit("base")
	else:
		# Clicking the already-active layout should leave it on.
		_restore_if_none_selected(base_layout)


func _on_tile_passives_layout_toggled(toggled_on: bool) -> void:
	if toggled_on:
		base_layout.button_pressed = false
		order_segments_layout.button_pressed = false
		EventBus.map_display_layout_changed.emit("tile_passives")
	else:
		# Clicking the already-active layout should leave it on.
		_restore_if_none_selected(tile_passives_layout)


func _on_order_segments_layout_toggled(toggled_on: bool) -> void:
	if toggled_on:
		base_layout.button_pressed = false
		tile_passives_layout.button_pressed = false
		EventBus.map_display_layout_changed.emit("order_segments")
	else:
		# Clicking the already-active layout should leave it on.
		_restore_if_none_selected(order_segments_layout)


## Toggle buttons turn themselves off on a second click. Put this one back on when no other layout is selected.
func _restore_if_none_selected(button: TextureButton) -> void:
	if base_layout.button_pressed or tile_passives_layout.button_pressed or order_segments_layout.button_pressed:
		return
	# Avoid re-emitting map_display_layout_changed for a layout that did not actually change.
	button.set_pressed_no_signal(true)


func _on_base_layout_mouse_entered() -> void:
	var tooltip := "Show Tile Cards"
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())


func _on_base_layout_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_tile_passives_layout_mouse_entered() -> void:
	var tooltip := "Show Tile Modifiers"
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())


func _on_tile_passives_layout_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_order_segments_layout_mouse_entered() -> void:
	var tooltip := "Show Card Trigger Order"
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())


func _on_order_segments_layout_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")
