class_name TriggerOrderMarker
extends Control

# One hex in the order-segments overlay. Colored fill matches the character-select preview.

const TILE_NORMAL := preload("res://assets/map/segment_icons/tile_normal.png")
const TILE_START := preload("res://assets/map/segment_icons/tile_segment_start.png")
const TILE_END := preload("res://assets/map/segment_icons/tile_segment_end.png")

@onready var background: TextureRect = $Background
@onready var order_label: Label = $OrderLabel


func setup(order: int, is_start: bool, is_end: bool) -> void:
	_ensure_nodes()
	size = Hex.HEX_TILE_SIZE
	custom_minimum_size = Hex.HEX_TILE_SIZE
	order_label.text = str(order)
	# A one-tile segment is both start and end. Prefer the start color.
	if is_start:
		background.texture = TILE_START
	elif is_end:
		background.texture = TILE_END
	else:
		background.texture = TILE_NORMAL


func _ensure_nodes() -> void:
	if background == null:
		background = $Background
	if order_label == null:
		order_label = $OrderLabel
