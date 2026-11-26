class_name CollectionDetailRowsSection
extends VBoxContainer

## A heading over a column of rows the caller builds (Station requirements, Station levels).

@onready var _heading: Label = $Heading
@onready var _rows: VBoxContainer = $Rows


func setup(heading: String) -> void:
	if not is_node_ready():
		await ready
	_heading.text = heading


func add_row(row: Control) -> void:
	if not is_node_ready():
		await ready
	_rows.add_child(row)
