class_name CollectionDetailNote
extends PanelContainer

## Teal banner on the parchment, such as how certain a Meal's origin is.

@onready var _body: RichTextLabel = $Body


func setup(body_bbcode: String) -> void:
	if not is_node_ready():
		await ready
	_body.text = body_bbcode
