class_name CollectionBioPart
extends VBoxContainer

## One unlocked bio part: "Part N" and its text.

@onready var _label: Label = $Label
@onready var _body: RichTextLabel = $Body


func setup(label: String, body_bbcode: String) -> void:
	if not is_node_ready():
		await ready
	_label.text = label
	_body.text = body_bbcode
