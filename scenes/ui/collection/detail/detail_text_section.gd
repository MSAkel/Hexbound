class_name CollectionDetailTextSection
extends VBoxContainer

## A heading and a paragraph of BBCode on the parchment (The story, Ability, Effect).

@onready var _heading: Label = $Heading
@onready var _body: RichTextLabel = $Body


func setup(heading: String, body_bbcode: String) -> void:
	if not is_node_ready():
		await ready
	_heading.text = heading
	_heading.visible = not heading.is_empty()
	_body.text = body_bbcode
