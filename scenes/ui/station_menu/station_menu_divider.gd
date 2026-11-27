@tool
extends HBoxContainer

## Section heading of the Station menu: a title between two ornaments and rules.

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_apply_title()


func _ready() -> void:
	_apply_title()


func _apply_title() -> void:
	(%Title as Label).text = title
