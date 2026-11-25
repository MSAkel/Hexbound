class_name CollectionLevelRow
extends HBoxContainer

## One Station level: "LV 3" and what reaching it gives, one line each.

const LINE_SCENE := preload("res://scenes/ui/collection/detail/level_line.tscn")

@onready var _level_label: Label = $LevelLabel
@onready var _lines: VBoxContainer = $Lines


func setup(level_text: String, lines: PackedStringArray) -> void:
	if not is_node_ready():
		await ready
	_level_label.text = level_text
	for line: String in lines:
		var label := LINE_SCENE.instantiate() as Label
		label.text = line
		_lines.add_child(label)
