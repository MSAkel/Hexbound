class_name UiVerticalDivider
extends ColorRect

# Height along the divider axis. Zero lets the parent container set the stretch.
@export var span: float = 0.0
@export_range(0.0, 1.0) var color_alpha: float = 0.22


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.43, 0.33, 0.19, color_alpha)
	custom_minimum_size = Vector2(2, span)
