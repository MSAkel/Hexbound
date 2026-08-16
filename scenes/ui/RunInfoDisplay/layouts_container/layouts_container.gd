extends PanelContainer

@onready var base_layout: TextureButton = $HBoxContainer/BaseLayout
@onready var tile_passives_layout: TextureButton = $HBoxContainer/TilePassivesLayout
@onready var order_segments_layout: TextureButton = $HBoxContainer/OrderSegmentsLayout

func _on_base_layout_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_passives_layout.button_pressed = false
		order_segments_layout.button_pressed = false
		EventBus.map_display_layout_changed.emit("base")

func _on_tile_passives_layout_toggled(toggled_on: bool) -> void:
	if toggled_on:
		base_layout.button_pressed = false
		order_segments_layout.button_pressed = false
		EventBus.map_display_layout_changed.emit("tile_passives")

func _on_order_segments_layout_toggled(toggled_on: bool) -> void:
	if toggled_on:
		base_layout.button_pressed = false
		tile_passives_layout.button_pressed = false
		EventBus.map_display_layout_changed.emit("order_segments")
