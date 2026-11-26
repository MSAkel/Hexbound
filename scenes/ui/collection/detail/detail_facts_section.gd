class_name CollectionDetailFactsSection
extends VBoxContainer

## Fun facts: a heading and one gold star row per fact.

const ROW_SCENE := preload("res://scenes/ui/collection/detail/detail_fact_row.tscn")

@onready var _heading: Label = $Heading
@onready var _rows: VBoxContainer = $Rows


func setup(heading: String, facts: Array[String]) -> void:
	if not is_node_ready():
		await ready
	_heading.text = heading
	for child in _rows.get_children():
		child.queue_free()
	for fact: String in facts:
		var row := ROW_SCENE.instantiate() as HBoxContainer
		(row.get_node("Text") as Label).text = fact
		_rows.add_child(row)
